#!/usr/bin/env bash
# claude-review.sh — Calls the Anthropic API to review a Terraform plan
# Usage: bash .github/scripts/claude-review.sh <plan_file> <output_file>
# Requires: ANTHROPIC_API_KEY env var, jq

set -euo pipefail

PLAN_FILE="${1:-tfplan.txt}"
OUTPUT_FILE="${2:-claude-review.md}"

if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "ANTHROPIC_API_KEY secret not set — skipping Claude review." > "$OUTPUT_FILE"
  exit 0
fi

if [ ! -f "$PLAN_FILE" ]; then
  echo "Plan file '$PLAN_FILE' not found — skipping Claude review." > "$OUTPUT_FILE"
  exit 0
fi

# Cap plan content at 40KB to stay within API limits
PLAN_CONTENT=$(head -c 40000 "$PLAN_FILE")

# Build prompt using a heredoc (safe from YAML escaping)
PROMPT=$(cat <<'PROMPT_END'
You are an expert AWS infrastructure engineer and Terraform specialist. Review this Terraform plan for an EKS cluster deployment.

Provide concise, actionable feedback on the following areas:

1. **Security** — IAM permissions (least-privilege?), security groups, encryption at rest/transit, public endpoint exposure, secrets handling
2. **Cost** — Instance sizing, NAT gateway config (single vs multi-AZ), storage type/size, data transfer, optimization opportunities
3. **Reliability** — Multi-AZ design, auto-scaling limits, health checks, node group sizing
4. **Best Practices** — AWS Well-Architected compliance, Terraform naming/tagging conventions, module version pinning
5. **Issues** — Errors, warnings, misconfigurations, or unexpected destructive changes

Focus on the highest-impact findings. Use markdown with clear headings and bullet points.

Terraform Plan:
PROMPT_END
)

# Append plan content to prompt
PROMPT="${PROMPT}
\`\`\`
${PLAN_CONTENT}
\`\`\`"

# Build JSON payload safely using jq — handles all special character escaping
PAYLOAD=$(jq -n \
  --arg content "$PROMPT" \
  '{
    model: "claude-opus-4-6",
    max_tokens: 4096,
    thinking: {type: "adaptive"},
    messages: [{role: "user", content: $content}]
  }')

echo "Calling Anthropic API..."

# Call the API
RESPONSE=$(curl -s https://api.anthropic.com/v1/messages \
  -H "Content-Type: application/json" \
  -H "x-api-key: ${ANTHROPIC_API_KEY}" \
  -H "anthropic-version: 2023-06-01" \
  -d "$PAYLOAD")

# Check for API-level error
API_ERROR=$(echo "$RESPONSE" | jq -r '.error.message // empty')
if [ -n "$API_ERROR" ]; then
  echo "Claude API error: ${API_ERROR}" > "$OUTPUT_FILE"
  exit 0
fi

# Extract text blocks — adaptive thinking produces thinking blocks first, then text
echo "$RESPONSE" | jq -r '[.content[] | select(.type == "text") | .text] | join("\n\n")' > "$OUTPUT_FILE"

echo "Review written to $OUTPUT_FILE"
