Generate descriptive, context-rich commit messages from staged files. Use when the user wants to create a commit message that explicitly states services changed, describes functionality changes in depth, and names specific components/API routes for tech fixes and bugfixes. Triggers include requests like 'create a commit message', 'write commit message for staged changes', 'generate git commit', or 'what should my commit message be'.Commit Message Generator
This skill generates comprehensive, user-friendly commit messages that provide clear context about changes without requiring readers to examine the code.
Core Principles

Explicitness over brevity - Always name the specific services, components, and routes affected
Depth for features - Feature changes get detailed descriptions of what changed and why
Conciseness for fixes - Technical fixes and bugfixes are concise but still name specific components
Self-contained context - Readers should understand changes without checking the wider codebase

Usage
When the user asks for a commit message:

Check staged files using git diff --staged or git status
Analyze the changes to understand:

Which services/modules are affected
What functionality changed
Whether it's a feature, fix, refactor, or other change type


Generate the message following the structure below
Present the message to the user for review

Message Structure
Format
<type>(<scope>): <summary>

<body>

[optional footer]
Type Options

feat - New feature or functionality
fix - Bug fix
refactor - Code restructuring without behavior change
perf - Performance improvement
docs - Documentation changes
test - Test additions or modifications
chore - Build process, dependencies, tooling
style - Code formatting, whitespace
ci - CI/CD configuration changes

Scope
Always be explicit about scope:

Service names: auth-service, payment-api, user-dashboard
Module names: authentication, billing, notifications
Component paths: api/v2/orders, frontend/checkout, workers/email-queue

For multi-service changes, list all affected services separated by commas:
feat(auth-service, user-api, admin-dashboard): add role-based permissions
Summary Line

50-72 characters (can extend to 100 for complex multi-service changes)
Imperative mood ("add" not "added", "fix" not "fixed")
Lowercase except for proper nouns
No period at the end
Specific components when relevant

Examples:
feat(payments-api): add webhook retry mechanism with exponential backoff
fix(auth/oauth): resolve token refresh race condition in parallel requests
refactor(api/v2/users): extract validation logic to middleware layer
Body - Features and Major Changes
For features and significant changes, provide detailed context:

What changed - Describe the new functionality or modification
Why it changed - Explain the motivation or problem being solved
How it works - Key implementation details
Impact - Effects on other services, APIs, or user experience

Structure:

Use bullet points for clarity
Start each point with a verb
Include specific file paths, function names, or API routes when relevant
Mention breaking changes explicitly

Example:
feat(checkout-service, payment-api): implement split payment support

- Add ability to split payments across multiple payment methods
  - New endpoint: POST /api/v2/payments/split
  - Accepts array of payment method objects with amount allocations
  - Validates total split amounts match order total

- Update checkout flow to handle split payment UI
  - New component: SplitPaymentSelector in frontend/checkout/components
  - Integrates with existing PaymentMethodList component
  - Shows real-time validation of split allocation

- Modify payment processing to handle atomic multi-payment transactions
  - Wrap all payment attempts in database transaction
  - Roll back all payments if any individual payment fails
  - Update PaymentRecord model to support parent_payment_id for split tracking

- Breaking change: payment_method field in Order model now accepts array type
  - Migration script provided in db/migrations/2024_02_14_split_payments.sql
  - Backward compatible for 30 days via compatibility layer
Body - Fixes and Technical Changes
For bugfixes and technical changes, be concise but explicit:

Component/route affected - Specific path or name
Problem - Brief description of the bug
Solution - How it was fixed
Root cause (optional) - If relevant and brief

Structure:

1-3 sentences or bullet points
Always name the specific component, file, or API route
Include error messages or symptoms if helpful

Examples:
fix(api/v2/orders/shipping): prevent null pointer in address validation

- OrderShippingService.validateAddress() failed when postal_code was null
- Add null check before regex validation in validators/address.py:45
- Return validation error instead of 500 error
fix(email-worker): resolve memory leak in template rendering

- EmailTemplateRenderer held references to compiled templates indefinitely
- Clear template cache after each batch in workers/email/renderer.py
- Reduces worker memory usage from 2GB to 400MB over 24h period
perf(api/users/search): optimize database query with composite index

- Add composite index on (last_name, first_name, created_at)
- Search queries now use index instead of full table scan
- Query time reduced from 1200ms to 45ms for typical searches
Footer
Include when relevant:

Breaking changes: BREAKING CHANGE: <description>
Issue references: Fixes #123, Closes #456, Refs #789
Co-authors: Co-authored-by: Name <email>
Migration notes: Migration: run db/migrations/script.sql before deploying

Decision Tree
Use this tree to determine message style:
Is it a feature or significant functionality change?
├─ YES → Use detailed body format
│         - Explain what, why, how
│         - List all affected services explicitly
│         - Describe functionality in depth
│         - Mention breaking changes and impacts
│
└─ NO → Is it a bug fix or technical change?
   ├─ YES → Use concise body format
   │         - Name specific component/route
   │         - Describe problem briefly
   │         - Explain solution
   │
   └─ NO → Is it a refactor, docs, or chore?
             - Name specific components
             - Brief description of change
             - Optional: reason if not obvious
Multi-Service Changes
When changes span multiple services:

List all services in scope - Don't use vague terms like "backend" or "api"
Organize by service - Use subsections if changes are complex
Show dependencies - Explain how services interact

Example:
feat(user-service, auth-service, notification-service): implement account deletion workflow

User Service:
- Add DELETE /api/v2/users/:id endpoint
- Soft delete user records with deleted_at timestamp
- Schedule cleanup job for associated data

Auth Service:
- Invalidate all active sessions for deleted user
- Remove OAuth tokens from oauth_tokens table
- Add user_id to revocation list cache

Notification Service:
- Send account deletion confirmation email
- Unsubscribe from all notification channels
- Archive notification history for 30 days before purge
Common Patterns
API Route Changes
Always include the full route path:
feat(api/v3/products): add inventory filtering endpoint
fix(api/v1/auth/login): handle expired session gracefully
Database Changes
Specify the table or schema:
feat(db/users): add two-factor authentication fields
fix(db/orders): correct foreign key constraint on customer_id
Frontend Components
Include component path:
feat(frontend/checkout/PaymentForm): add saved payment methods dropdown
fix(frontend/dashboard/UserProfile): resolve avatar upload race condition
Configuration Changes
Name the config file or system:
chore(docker-compose): update postgres to version 15
fix(nginx/api-gateway): correct proxy timeout configuration
Examples Collection
Feature with Breaking Change
feat(api/v2/subscriptions, billing-worker): implement usage-based pricing

- Add new pricing model supporting usage tiers and overages
  - New endpoint: POST /api/v2/subscriptions/usage-events
  - Accepts event type, quantity, timestamp, and metadata
  - Validates against subscription plan limits

- Update billing worker to calculate usage charges
  - New UsageBillingCalculator in workers/billing/usage.py
  - Aggregates usage events monthly with tier pricing
  - Handles proration for mid-cycle plan changes

- Modify subscription schema to support hybrid pricing
  - Add usage_config JSON field to subscription_plans table
  - Track current usage period in subscription_usage_tracking table

BREAKING CHANGE: subscription webhooks now include usage_charges array
- Update webhook handlers to process new usage_charges field
- Previous flat_rate field deprecated but still populated for 60 days
- Migration guide: docs/migrations/usage-based-pricing.md
Bugfix with Root Cause
fix(auth-service/session): prevent session fixation vulnerability

- SessionManager.create() reused session IDs from expired sessions
- Generate new UUID for each session in auth/session_manager.py:78
- Invalidate all existing sessions on password change
- Root cause: session cleanup job wasn't purging ID pool
Performance Optimization
perf(api/search, elasticsearch-sync): optimize product search indexing

- Batch Elasticsearch updates in 1000-document chunks
- Add connection pooling for ES client (max 20 connections)
- Implement exponential backoff retry for failed batches
- Index sync time reduced from 45min to 8min for 100k products
Multi-Component Refactor
refactor(api/v2, frontend/shared): extract common validation logic

API Changes:
- Create shared validators package in api/v2/validators/
- Move email, phone, address validators from inline definitions
- Used in: user endpoints, checkout endpoints, profile endpoints

Frontend Changes:
- Create validation utility in frontend/shared/utils/validators.ts
- Matches server-side validation rules for client-side checks
- Used in: UserForm, CheckoutForm, AddressInput components

Benefits:
- Single source of truth for validation rules
- Easier to maintain and test validation logic
- Consistent error messages across API and frontend
Error Handling
If unable to access staged files:
"I couldn't access the staged files. Please run `git add` to stage your changes, 
or provide the output of `git diff --staged` so I can analyze the changes."
If no files are staged:
"No files are currently staged. Stage your changes with `git add <files>` first, 
then I can generate a commit message."
If changes are too complex to analyze:
"The changes are quite extensive. Could you tell me:
1. What's the main purpose of this commit?
2. Which services or components are primarily affected?
3. Is this a feature, fix, or refactor?"
Linear ref
Resolve the Linear issue identifier in this order:
1. If the user passed an identifier in args (e.g. `/create_commit_msg TEL-10`), use it.
2. Otherwise, run `cat .linear-issue 2>/dev/null` — if it returns a non-empty value, use that.
3. If neither source yields an identifier, omit the footer line entirely.

When an identifier is found, append to the commit footer:
  Refs: TEL-10  # GA4 + AI Data Room

The file has two lines: line 1 = issue identifier, line 2 = project name. Format as `Refs: <issue>  # <project>`.
If only line 1 is present (no project name), use `Refs: TEL-10` without the comment.

Quality Checklist
Before presenting the commit message, verify:

 Specific services/components named (not "backend" or "various files")
 All changed services listed in scope
 For features: what, why, and how are explained
 For fixes: specific component and problem named
 API routes include full path (e.g., /api/v2/users/:id)
 Breaking changes explicitly called out
 Message is understandable without reading the code
 Type and scope are accurate
 Summary line is imperative mood and concise
 Linear ref appended if provided in args

Workflow

Gather information

bash   git diff --staged --name-only  # Get list of files
   git diff --staged              # Get actual changes

Categorize changes

Group by service/module
Identify change type (feat/fix/refactor/etc.)
Determine if breaking changes exist


Extract key information

New functions/endpoints added
Modified behavior
Deleted code or deprecated features
Database schema changes
Configuration changes


Compose message

Start with type and scope
Write summary line
Add detailed body if feature/major change
Include footer if needed


Review and present

Check against quality checklist
Format for readability
Offer to revise based on user feedback
