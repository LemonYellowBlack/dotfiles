#!/bin/bash
# Audit log hook — logs every tool call to ~/claude-audit.log
# Only active when ~/.claude-audit-on exists (toggle with: claude-audit on/off)

[ -f ~/.claude-audit-on ] || exit 0

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}')
SESSION=$(echo "$INPUT" | jq -r '.session_id // "unknown"')

echo "$(date -Iseconds) | session=$SESSION | tool=$TOOL | input=$TOOL_INPUT" >> ~/claude-audit.log
