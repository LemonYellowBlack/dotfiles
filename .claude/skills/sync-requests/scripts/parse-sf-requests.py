#!/usr/bin/env python3
"""Query SF Request__c via sf CLI and output a structured summary."""

import json
import re
import subprocess
import sys

SOQL = (
    "SELECT Id, Name, Status__c, Priority__c, Request_Type__c, "
    "CreatedDate, Due_Date__c, Requester_s__c, "
    "ClickUp_Ticket_URL__c, ClickUp_Ticket_ID__c, "
    "Request_Details__c, Outcome_Statement__c, Next_Step__c, "
    "Page_URL__c, Impacted_Account__c "
    "FROM Request__c "
    "WHERE Owner.Name = 'Robbie Szymczak' "
    "AND Status__c NOT IN ('Complete', 'Cancelled', 'Closed') "
    "ORDER BY CreatedDate DESC"
)


def strip_html(text):
    """Remove HTML tags and collapse whitespace."""
    text = re.sub(r"<[^>]+>", " ", text)
    return re.sub(r"\s+", " ", text).strip()


def truncate(text, max_len=200):
    return text[:max_len] + "..." if len(text) > max_len else text


def parse_sf_json(raw):
    """Strip CLI warning lines and parse the JSON payload."""
    lines = raw.split("\n")
    start = next(i for i, l in enumerate(lines) if l.strip().startswith("{"))
    return json.loads("\n".join(lines[start:]))


def main():
    result = subprocess.run(
        ["sf", "data", "query", "--query", SOQL, "--target-org", "prod", "--json"],
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        print(f"SF CLI error: {result.stderr.strip()}")
        sys.exit(1)

    try:
        data = parse_sf_json(result.stdout)
    except Exception as e:
        print(f"Error parsing SF output: {e}")
        sys.exit(1)

    records = data["result"]["records"]
    if not records:
        print("No open Request records found.")
        return

    missing = [r for r in records if not r.get("ClickUp_Ticket_URL__c")]
    linked = [r for r in records if r.get("ClickUp_Ticket_URL__c")]

    if missing:
        print(f"### {len(missing)} Request(s) WITHOUT ClickUp ticket:\n")
        for i, r in enumerate(missing, 1):
            details = truncate(strip_html(r.get("Request_Details__c") or ""))
            print(
                f"  {i}. **{r['Name']}** | {r['Status__c']}"
                f" | Priority: {r.get('Priority__c', '—')}"
                f" | Created: {r['CreatedDate'][:10]}"
                f" | Due: {r.get('Due_Date__c', '—')}"
                f" | Requester: {r.get('Requester_s__c', '—')}"
            )
            print(f"     SF ID: {r['Id']}")
            if details:
                print(f"     Details: {details}")
    else:
        print("All open Requests already have ClickUp tickets!")

    if linked:
        print(f"\n### {len(linked)} Request(s) already linked:\n")
        for r in linked:
            print(f"  - {r['Name']} -> {r['ClickUp_Ticket_URL__c']}")


if __name__ == "__main__":
    main()
