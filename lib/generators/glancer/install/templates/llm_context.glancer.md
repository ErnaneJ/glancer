--glancer-ignore

# Glancer LLM Context Template
#
# This file lets you define custom business rules, domain logic,
# naming conventions, and assumptions about your data model
# that the language model should take into account when answering questions.

## How It Works

- These rules and notes will be embedded and used as retrieval context.
- They **do not need to be machine-parsable** — use natural language.
- Be specific and concise. Avoid redundant or vague information.

## Business Rules

- "Users with role = 'admin' are considered system administrators."
- "Orders with status = 'cancelled' should not be counted in sales totals."
- "Only 'paid' invoices should be considered for revenue aggregation."
- "Products may belong to multiple categories via `product_categories` join table."

## Domain Definitions

- "`vendas` = sales"
- "`usuarios` = users or system operators"
- "`filiais` = branches or physical offices"
- "A `lead` represents a potential customer, not yet converted to a client."

## Special Table Considerations

- "`users` table stores authentication data and personal details. Use with care."
- "`clients_blacklists` table indicates blocked clients; should be checked before allowing new orders."
- "`blazer_*` tables are internal and should be ignored."

## Common Query Patterns

- "When grouping by month, use the `created_at` column, unless otherwise specified."
- "Default date range for metrics is the last 30 days unless the question says otherwise."

## Output Expectations

- "Always alias columns using `AS` with a human-readable label."
- "All queries should return fields in snake_case."
- "Include rows with zero results when grouping by time (use LEFT JOINs or CTEs if needed)."

## 📝 Notes

- You can add Markdown formatting here, but it's optional.
- Keep this file short and relevant. Avoid dumping full tables or schemas here.
- This file is **ignored** by Glancer indexing unless you remove the `--glancer-ignore` line.