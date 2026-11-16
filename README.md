# Snowflake CoCo Foundations (Cortex Code Desktop edition)
<!-- ------------------------ -->
## Overview

Cortex Code (CoCo) is Snowflake's AI coding agent built to accelerate data and AI workflows. It understands your data catalog, executes SQL as your identity, and integrates natively with dbt, Git, Python, and Streamlit.

This edition of the lab uses **Cortex Code Desktop**, the local desktop IDE for CoCo. If you are running the lab in the browser, use the [Snowsight edition](README.md) instead.

You will complete a hands-on workshop covering three real-world scenarios: building a Dynamic Table pipeline, maintaining and evolving it, and creating a Cortex Agent with a semantic view.

### Prerequisites
- A Snowflake account with CoCo enabled
- A macOS or Windows machine where you can install Cortex Code Desktop
- The **SYSADMIN** and **SECURITYADMIN** roles (the setup script switches to both). If you do not have them, ask your admin to run the two setup scripts and grant you `COCO_WORKSHOP_ROLE`.
- Set **SYSADMIN** as the role on your CoCo Desktop connection, so CoCo works as the same role that owns the lab objects.

### What You'll Learn
- How to install CoCo Desktop and connect it to Snowflake
- How to build a Dynamic Table pipeline with CoCo
- How to maintain a pipeline as requirements change
- How to create a Cortex Agent with a semantic view and evaluate its quality

### What You'll Build
- A multi-source Accounts Payable (AP) invoice pipeline using Dynamic Tables
- A Cortex Agent grounded on a semantic view, with an evaluation against a golden question set

<!-- ------------------------ -->
## Install and Connect CoCo Desktop

1. Download and install CoCo Desktop from the [Cortex Code Desktop documentation](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-desktop) page.
2. Launch the app. The onboarding flow asks you to **Connect to Snowflake**:
   - If you already have a `~/.snowflake/connections.toml`, your existing connections are listed. Select one and click **Next**.
   - Otherwise click **Add connection**, enter your account identifier (`orgname-accountname`) and user, choose an authentication method, then click **Sign in**. For SSO or OAuth, complete sign-in in your browser.
3. Finish the remaining onboarding steps (default mode and theme). The defaults are fine for this lab.
4. Tip: you can reopen the connection manager at any time by typing `/connections` in the chat input.

Full details: [Onboarding and authentication](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-desktop/onboarding-and-authentication).

### Open the lab folder

CoCo Desktop works against a local folder, so files it creates (SQL, semantic views, agent specs) land on your machine where you can review and version them.

1. Clone or download this repo:
   ```
   git clone https://github.com/sfc-gh-teastabrook/cortex-code-foundations.git
   ```
2. In CoCo Desktop, open the `cortex-code-foundations` folder (**File > Open Folder...**).
3. Open the chat panel with **Open Chat** if it is not already visible.

### Desktop controls used in this lab

| Control | Where to find it |
| --- | --- |
| Agent / Plan mode | The mode picker under the chat input (`Agent`, `Plan`), or press `Shift+Tab` to toggle |
| Attach a file | The **+** / **Attach file** button in the chat input, or right-click a file and choose **Add File to Chat** |
| Use a skill | Type `/` followed by the skill name in the chat input |
| Accept CoCo's edits | **Keep** on an individual change, or **Accept All Changes** |
| Run SQL in a file | **Execute SQL** for the current statement, **Run All** for the whole file (both on the SQL editor toolbar and in the Command Palette) |
| Approvals | The approval picker at the bottom-left of the chat input. Make sure it is set to **Default Approvals** for this lab so you see and approve each action CoCo takes. This setting applies to every chat on your machine, so check it even if you have not changed it in this session. |

<!-- ------------------------ -->
## Lab Setup

Run the setup scripts in the `assets/` folder to create the workshop environment and load sample data.

### Step 1: Create the Workshop Environment

1. In the Explorer, open `assets/00_snowday_setup.sql`.
2. Run the whole file with **Run All**. Results appear in the **SQL Results** view. This creates:
   - `COCO_WORKSHOP` database
   - `PIPELINE_LAB` and `SOURCE_DATA` schemas
   - `COCO_WORKSHOP_WH` warehouse (X-Small, auto-suspend 120s)
   - Tags for optional governance exercises

### Step 2: Load Sample Data

1. Open `assets/00_sample_data.sql`.
2. Run it with **Run All**. This creates and populates:
   - `BRONZE_SAP_AP_INVOICES`: 15 SAP invoices (USD, EUR, GBP)
   - `BRONZE_ORACLE_AP_INVOICES`: 15 Oracle invoices (USD, EUR, GBP)
   - `BRONZE_BAAN_AP_INVOICES`: 11 Baan rows (EUR, GBP), including one known duplicate invoice, used in Demo 2
   - `BRONZE_WORKDAY_AP_INVOICES`: 10 Workday invoices (USD, GBP, EUR), used in Demo 2
   - `AGENT_EVAL_SET`: 15 golden evaluation questions, used in Demo 3

> **Tip:** You can also ask CoCo to do this for you: `Run assets/00_snowday_setup.sql and then assets/00_sample_data.sql, and confirm the objects were created.`

> **Check:** both scripts create objects as **SYSADMIN**. If CoCo later reports that a `BRONZE_*` table "does not exist or not authorized", your connection is using a different role. Switch it to SYSADMIN with **Change Role** (or `/connections`) and retry.

<!-- ------------------------ -->
## Workshop Overview

This workshop follows a single Accounts Payable (AP) invoices storyline across three demos, from data discovery through operationalization and optional agent design.

> **Stuck?** The `reference/` folder has working SQL you can compare against or run to catch up:
> - `reference/silver_ap_invoices.sql`: the Silver Dynamic Table as it should be at the end of Demo 2 (all four sources and business rules)
> - `reference/sv_ap_analytics.sql`: the Demo 3 semantic view, with a validation query
>
> CoCo's output will differ from these files, and that's expected. Use them to check your results, not as the only correct answer.

<!-- ------------------------ -->
## Demo 1: Pipeline Builder

Finance needs a trusted AP invoices layer. SAP and Oracle invoice data already exist in Snowflake, but there is no standardized Silver object yet. The goal is a single, well-modeled table that can be explained, monitored, and evolved without repeating discovery work each time a requirement changes.

### Step 1.1: Discover the Source

Begin with data discovery, a natural first move when you enter a new schema.

**Prompt:**
```
What tables are in the `COCO_WORKSHOP.SOURCE_DATA` schema?
For each table, give me a one-line description of what it appears to contain and identify
which ones are most relevant to an AP invoices Silver layer.
```

> **What to look for:** A short list of tables relevant to the AP workflow, with enough description to orient yourself without manually opening each object. You can also browse the same objects in the **Snowflake Catalog** view.

### Step 1.2: Compare SAP and Oracle Invoice Schemas

Once you know which tables matter, compare them to get the shortest path to a clean normalization plan.

**Prompt:**
```
Compare the columns between
COCO_WORKSHOP.SOURCE_DATA.BRONZE_SAP_AP_INVOICES and
COCO_WORKSHOP.SOURCE_DATA.BRONZE_ORACLE_AP_INVOICES.
Return:
- Equivalent fields with different names
- Fields that require type normalization or default values
- Differences that should remain open questions instead of becoming hidden assumptions
```

> **What to look for:** Equivalent business fields with different names, normalization work you should expect before building Silver, and open questions that should stay explicit for later review.

### Step 1.3: Generate the Silver Dynamic Table

In this step CoCo uses the **dynamic-tables** skill to design and build the Dynamic Table.

**1.3.1 - Check the dynamic-tables skill is available**

CoCo Desktop ships with a bundled `dynamic-tables` skill, so there is nothing to upload.

1. In the chat input type **/dynamic**. You should see **dynamic-tables** in the skill list.
2. *Only if it does not appear* (for example, it has been disabled in **Agent Settings > Skills**, or you want to use the lab's custom version): unzip `assets/dynamic-tables.zip` and copy the `dynamic-tables` folder into `.snowflake/cortex/skills/` inside your lab folder (so the path is `cortex-code-foundations/.snowflake/cortex/skills/dynamic-tables/`). CoCo auto-discovers project skills there. Type **/dynamic** again to confirm. Alternatively, register the unzipped folder via **Agent Settings > Skills > Local Skills > +**.

**1.3.2 - Get CoCo to design the dynamic table**

1. Switch the mode picker to **Plan**. Plan mode lets CoCo think through a multi-step task and propose a plan before it changes anything.
2. Run the following prompt:

```
Use database COCO_WORKSHOP and schema PIPELINE_LAB for outputs.
Create a Dynamic Table called SILVER_AP_INVOICES in my current schema by combining
COCO_WORKSHOP.SOURCE_DATA.BRONZE_SAP_AP_INVOICES and
COCO_WORKSHOP.SOURCE_DATA.BRONZE_ORACLE_AP_INVOICES.
```

> **What to look for:** A clean first-pass Dynamic Table definition with explainable design choices. Note how CoCo outlines its approach, including the SQL it is proposing to create. In Desktop the plan is also saved as a markdown file under `.snowflake/cortex/plans/` so you can open and edit it.

**1.3.3 - Get CoCo to build the plan**

1. Either click **Build** on the plan card (or run **Build from Plan** from the Command Palette), or switch the mode picker back to **Agent** and enter:

```
Proceed with the plan. Create a new SQL file in the lab folder with all the code.
```

> **What to look for:** CoCo creates a new `.sql` file in your lab folder and deploys the Dynamic Table. It may ask you to approve the SQL it runs.

**1.3.4 - Review the SQL file that CoCo generated**

1. Open the new file and review the diff. Click **Keep** (or **Accept All Changes**) to retain CoCo's changes.

> **NOTE:** If CoCo did not deploy the Dynamic Table, open the SQL file and use **Run All**.

### Step 1.4: Explore the dynamic-tables skill

Skills are reusable workflows that tell CoCo how to handle a specific Snowflake task. Instead of responding in a completely open-ended way, a skill provides domain context, expected inputs, a defined process, and structured outputs.

1. See what skills are available:

    ```
    List the skills you have
    ```

2. Inspect the Dynamic Tables skill:

    ```
    What does the dynamic-tables skill do? Summarize when I should use it,
    what inputs it expects, and what kinds of output it returns.
    ```

3. Apply it to the `SILVER_AP_INVOICES` table you created. Type **/dynamic-tables** in the chat input, select the skill, then paste:

    ```
    Analyze the Dynamic Table SILVER_AP_INVOICES in my current schema.
    Return:
    1. The recommended TARGET_LAG choice for this workflow and why
    2. SQL to inspect current state, lag, and refresh history
    3. The main failure or staleness patterns to watch for
    4. A short best-practices checklist for operating this table well
    ```

> **What to look for:** A runbook you would actually keep: a couple of monitoring queries and a concise operating checklist, not generic advice.

### Step 1.5: Save a Proof Query *(optional)*

1. Ask CoCo for a proof query and have it saved to the lab folder:

    ```
    Give me one concise proof query for SILVER_AP_INVOICES that shows record counts by SOURCE_SYSTEM and is easy to rerun after future changes. Save it as proof_query.sql.
    ```

2. Open `proof_query.sql` and run it with **Execute SQL** any time you change the pipeline.

You now have a Silver-grade AP invoices Dynamic Table that updates automatically from the Bronze tables, a runbook generated with the dynamic-tables skill, and a proof query saved as a file in your project.

<!-- ------------------------ -->
## Demo 2: Managing changing requirements

A month later, the business sends a set of new requirements for the AP invoices pipeline. New source systems must be added, field requirements have changed, and some definitions need clarification.

### The new requirements

The Finance Transformation PMO has prepared three CSV files, already in the `assets/` folder of your lab:

- `sample_business_requirements_source_onboarding.csv`: new source systems (Baan, Workday), owners, priorities, and go-live targets
- `sample_business_requirements_column_mapping.csv`: field-level mappings for both new sources into the Silver schema
- `sample_business_requirements_business_rules.csv`: BR-001 through BR-010 covering status normalization, deduplication logic, currency handling, and open questions

### Step 2.1: Ask CoCo to help you understand the new requirements

1. Attach the three CSV files to the chat. Either click **+** / **Attach file** in the chat input and select them, or select all three in the Explorer, right-click, and choose **Add File to Chat**. (You can also just reference them by path in the prompt, because CoCo can read files in your lab folder.)
2. Paste the following prompt:

    ```
    Review the attached business requirements for changes to the AP Invoices pipeline. Summarize the changes that affect the AP invoices pipeline.
    Return:
    - New source systems being introduced
    - New fields or business rules that affect the Silver layer
    - Ambiguities or open questions that should be resolved before implementation
    ```

> **What to look for:** A clear distinction between requirements and assumptions, and proposed changes.

### Step 2.2: Ask CoCo to prepare a plan for the required changes

1. Switch the mode picker to **Plan**.
2. Paste this prompt:

    ```
    Create a plan for implementing the new business requirements.
    ```

> **What to look for:** A plan that outlines the proposed changes to the AP invoice pipeline.

### Step 2.3: Apply the Update

1. Switch back to **Agent** mode and paste:

    ```
    Proceed with the build. Update the existing SQL file with the changes. Also return:
    - A short explanation of how the new sources map into the common schema
    - Any assumptions that require engineering review
    - Validation queries that prove the update worked
    ```

> **What to look for:** Updated SQL, explainable source mapping, explicit assumptions, and validation queries. Check in particular that:
> - Baan has **10** rows in Silver, not 11 (BR-003 removed the duplicate `BN-2025-1004`).
> - Every `APPROVAL_STATUS` is `APPROVED` or `PENDING` (BR-001).
> - The Dynamic Table has an explicit `TARGET_LAG` such as `'1 hour'` (BR-009). `DOWNSTREAM` on its own would stop it refreshing, because nothing reads from it yet.
>
> **Presenter note:** some new rules deliberately reverse choices CoCo may have made in Demo 1. For example, BR-005 keeps payment terms as-is at Silver, and BR-008 drops system-specific columns such as company codes. This is part of the exercise: see whether CoCo spots and explains the change.

### Step 2.4: Review the changes in the SQL file

1. Open the SQL file. Desktop shows CoCo's edits as an inline diff; use **Open Changes in Diff Editor** for a side-by-side view.
2. Click **Keep** (or **Accept All Changes**) to retain the changes.
3. If you created `proof_query.sql` in Step 1.5, rerun it to confirm Baan (10 rows) and Workday (10 rows) now appear in the counts.

> **NOTE:** If CoCo did not deploy the changes, open the SQL file and use **Run All**.

At this point you have built a dynamic data pipeline and updated it in response to changing business requirements.

<!-- ------------------------ -->
## Demo 3: Build an Agent on the Accounts Payable data *(Optional)*

By this point you have a curated AP invoices Silver object. Now is the right moment to introduce agents, because you can keep the AI experience grounded in trusted, well-modeled data.

### Step 3.1: Define the Agent Use Case

Use CoCo to help define the value of creating a Cortex Agent on top of the AP invoices data.

```
Help me define the value of a Cortex agent built on top of SILVER_AP_INVOICES data in my current schema.
Suggest:
- The primary audience for the agent
- The top five business questions the agent might answer
- Guardrails that keep the agent grounded in the curated data
- Any semantic descriptions that would improve answer quality
```

### Step 3.2: Create a Semantic View over the Silver Data

Create a semantic view that exposes business-friendly dimensions and measures. This is the object the agent relies on for most of its answers.

1. Paste the following prompt:
    ```
    Let's start by building the semantic view.
    Create a semantic view called SV_AP_ANALYTICS over SILVER_AP_INVOICES.
    It should support natural language questions like:
    - "Total AP spend by vendor in 2025"
    - "Invoice count by month and business unit"
    - "Top 10 vendors by pending invoice amount"
    Return:
    - A complete semantic view definition as a new sql file that clearly names business measures and dimensions including semantic definitions.
    - Any assumptions you are making about grain, time dimensions, and vendor identifiers.
    ```

> **What to look for:** A semantic view definition with clear business measures, dimensions, and assumptions.
>
> **Data note:** the sample invoices are dated January to June 2025, so relative windows such as "last 12 months" return no rows. The data also has no paid flag, so "pending" (`APPROVAL_STATUS = 'PENDING'`) is the closest measure to "unpaid". Expect CoCo to call both points out as assumptions.

2. Click **Keep** to retain the new file.
3. Ask CoCo to deploy and validate it:

    ```
    Deploy the semantic view and run a validation query against it to verify it is working
    ```

> **NOTE:** CoCo may ask you to approve the SQL that creates the semantic view.

### Step 3.3: Create a Cortex Agent

Now create a Cortex Agent that uses the semantic view to answer natural-language questions.

```
Build a Cortex Agent on SV_AP_ANALYTICS to answer natural language questions about AP spend and invoice aging.
```

If prompted, approve CoCo saving the agent specification and deploying the agent.

### Step 3.4: Using skills to assess code against best practice

Skills can include sub-skills that verify your work against best practices. The bundled **agent-studio** skill includes an audit workflow for semantic views. Type **/agent-studio**, select it, then paste:

```
Help me audit my Semantic View for best practices and provide suggestions.
```

> **What to look for:** An evaluation of the semantic view against best practices, with concrete suggestions for improving answer quality.

### Step 3.5: Evaluate the agent against a golden question set *(optional)*

The setup loaded `COCO_WORKSHOP.SOURCE_DATA.AGENT_EVAL_SET`: 15 questions with expected answers and SQL, covering core, variation, edge-case, ambiguous, and data-validation questions.

```
Use the questions in COCO_WORKSHOP.SOURCE_DATA.AGENT_EVAL_SET to evaluate my agent.
For each question, compare the agent's answer with EXPECTED_ANSWER (and the result of EXPECTED_SQL where present).
Return a pass/fail table, the overall score, and the top three changes to the semantic view or agent instructions that would fix the failures.
```

> **What to look for:** The ambiguous questions ("Show me recent invoices", "Which vendors are problematic?") should get a clarifying question or a stated default, not a guess.

<!-- ------------------------ -->
## Set Up the Auto-Grader if you want a digital badge (optional)

If you collect digital badges, complete this step to receive one.

1. Navigate to: https://northstar.streamlit.app/Auto-Grader
2. Select the **CoCo Foundations: Getting Started with CoCo** workshop.
3. Enter your Email and Name. **Your email must be the same as the one you used to register.**
4. Click **Generate SQL** and copy the SQL that is generated.
5. In CoCo Desktop, create a new file in the lab folder called `autograder.sql` and paste the SQL into it.
6. Run it with **Run All**.
7. If you completed each step correctly you will see a "**Congratulations! You have successfully completed the Cortex Code Foundations workshop!**" message in **SQL Results**.

And you are done.

<!-- ------------------------ -->
## Conclusion And Resources

The core pattern is simple: pick one concrete object, ask CoCo for one concrete artifact, and keep the result in the project. With CoCo Desktop, "the project" is a real folder on your machine, so everything CoCo produced in this lab (Dynamic Table SQL, proof query, semantic view, plans) is ready to commit to Git.

In Demo 1, this was a Dynamic Table to move data from the Bronze layer to the Silver layer, a small Dynamic Table runbook, and a proof query you can rerun after every change. In Demo 2, it was turning new business requirements into a structured, reviewable change plan. In Demo 3, you saw how skills can be used to design and build new objects (a semantic view and an agent) and to assess work against best practice.

### What You Learned
- How to install CoCo Desktop, connect it to Snowflake, and work from a local project folder
- Data discovery, schema comparison, and Dynamic Table creation
- Using Plan mode to let CoCo think through multi-step assignments and produce a reviewable plan before creating and running code
- Using bundled skills (`dynamic-tables`, `agent-studio`) and how to add a custom skill as a project skill

### Related Resources
- [Cortex Code Desktop Documentation](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-desktop)
- [Dynamic Tables Overview](https://docs.snowflake.com/en/user-guide/dynamic-tables-intro)
- [Cortex Agents Overview](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents)
- [Cortex Semantic Views Overview](https://docs.snowflake.com/en/user-guide/views-semantic/overview)
