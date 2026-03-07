# Security Incident Response Reference

---

## Incident Classification

| Priority | Definition | Response SLA | Examples |
|----------|------------|--------------|---------|
| P0 | Active breach, data exfiltration in progress, ransomware | Immediate; 24/7 | RCE exploit active, credentials leaked and used, data exfil detected |
| P1 | Confirmed vulnerability with high exploitation risk; service outage affecting auth | 2 hours | Critical CVE in production dependency, auth bypass discovered, IAM keys exposed |
| P2 | Suspected compromise; significant vulnerability not yet exploited | 8 hours | Anomalous access patterns, exposed secrets (not yet used), SSRF found |
| P3 | Policy violation; low-risk finding | 48 hours | Weak password found, misconfigured header, minor dependency CVE |

---

## Incident Response Phases

```
Detect → Triage → Contain → Eradicate → Recover → Post-Mortem
```

---

## Playbook: Credential / Secret Leak

**Trigger**: Secret found in public GitHub repo, Slack, or paste site.

```bash
# Step 1: IMMEDIATELY revoke (do not wait for confirmation)
# AWS keys
aws iam delete-access-key --access-key-id AKIAIOSFODNN7EXAMPLE
# Or if unsure which role, disable all keys for suspected user
aws iam list-access-keys --user-name suspected-user
aws iam update-access-key --access-key-id KEY_ID --status Inactive

# Database password
# Rotate immediately in Vault or Secrets Manager
vault write database/rotate-root/mydb

# JWT signing key
# 1. Generate new key
# 2. Deploy new key (start issuing new tokens)
# 3. Maintain old key for verification only (for TTL period)
# 4. After access token TTL expires, remove old verification key

# Step 2: Audit — what was accessed with the leaked credential?
# AWS CloudTrail
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=AccessKeyId,AttributeValue=AKIAIOSFODNN7EXAMPLE \
  --start-time 2025-01-01 --end-time 2025-12-31 \
  --output json > cloudtrail-audit.json

# Step 3: Assess impact
# - Was any data read/exfiltrated?
# - Were any resources created (backdoor IAM users, EC2, etc.)?
# - Any data deleted or encrypted (ransomware)?
grep '"eventName": "CreateUser"' cloudtrail-audit.json  # suspicious if found
grep '"eventName": "GetObject"' cloudtrail-audit.json   # S3 reads

# Step 4: Communicate
# - Notify security lead immediately
# - If PII involved: start breach notification timer (GDPR: 72 hours)
```

---

## Playbook: Data Breach (Unauthorized Access to PII/PCI)

```python
BREACH_RESPONSE_CHECKLIST = {
    "immediate_0_to_1h": [
        "Isolate affected systems (revoke tokens, disable accounts, block IPs)",
        "Preserve evidence (snapshots, logs) before remediation",
        "Alert incident commander and security team",
        "Start legal/DPO notification thread",
        "Assess scope: how many records, what data types"
    ],
    "short_term_1_to_8h": [
        "Identify attack vector (how did attacker get in)",
        "Review logs for full extent of access",
        "Remediate vulnerability",
        "Reset all potentially compromised credentials",
        "Notify affected customers if required",
        "File GDPR/HIPAA breach notification if applicable"
    ],
    "medium_term_8_to_72h": [
        "Regulatory notifications (GDPR: supervisory authority within 72h)",
        "Credit monitoring for affected individuals if SSN exposed",
        "Customer communication (if externally visible breach)",
        "Full forensic analysis",
        "Board/executive briefing"
    ],
    "post_incident": [
        "Post-mortem within 5 business days",
        "Root cause analysis",
        "Control improvements",
        "Repeat scenario testing"
    ]
}
```

---

## Playbook: RCE (Remote Code Execution)

```bash
# Step 1: Isolate compromised system
# Cloud: Quarantine — remove from load balancer, apply security group blocking all traffic
aws ec2 modify-instance-attribute --instance-id i-1234 \
  --groups sg-quarantine  # sg-quarantine: no inbound, limited outbound (S3 for forensics)

# Kubernetes: Cordon and isolate pod
kubectl cordon node-1  # prevent new pods
kubectl label pod compromised-pod "quarantine=true"
# Apply NetworkPolicy to block all traffic
kubectl apply -f quarantine-netpolicy.yaml

# Step 2: Forensic evidence collection (BEFORE remediation)
# Memory dump
aws ssm send-command --instance-ids i-1234 \
  --document-name AWS-RunShellScript \
  --parameters 'commands=["sudo dd if=/proc/kcore | aws s3 cp - s3://forensics-bucket/memdump.raw"]'

# Process list, open files, network connections
lsof -n > /tmp/forensics-lsof.txt
ss -tulpn > /tmp/forensics-ss.txt
ps auxf > /tmp/forensics-ps.txt
cat /proc/*/cmdline 2>/dev/null | strings > /tmp/forensics-cmdlines.txt

# Step 3: Identify the exploit
# Check web server logs for the attack vector
grep -E "(..\/|cmd=|exec=|eval\(|base64_decode)" /var/log/nginx/access.log
# Check recently modified files
find /var/www -mmin -60 -type f 2>/dev/null  # modified last hour

# Step 4: Check for persistence mechanisms
# Crontabs, new SSH keys, new users, modified sudoers
crontab -l -u root
ls -la ~/.ssh/authorized_keys
grep -v "^#" /etc/passwd | awk -F: '$3==0{print}'  # root-equiv users
cat /etc/sudoers.d/*
```

---

## Forensic Logging Requirements

What to log to enable forensic reconstruction:

```python
FORENSIC_LOG_FIELDS = {
    # Required for every request
    "timestamp": "ISO8601 with timezone",
    "request_id": "UUID for correlation",
    "user_id": "authenticated user ID (or 'anonymous')",
    "ip_address": "client IP (real IP, not proxy)",
    "method": "HTTP method",
    "path": "request path (NOT query string if sensitive)",
    "status_code": "HTTP response status",
    "duration_ms": "request duration",
    "user_agent": "client user agent string",

    # Security-specific
    "auth_method": "bearer/apikey/session/none",
    "mfa_used": "bool",
    "permission_denied": "bool — flagged for security review",
    "data_accessed": "table names (not values)",
    "rows_affected": "count",
}

# Log retention for forensics:
# Authentication events: 2 years
# Access to PII: 7 years (legal requirement)
# General app logs: 90 days
# Security events: 1 year minimum
```

---

## CVE Response Process

```
CVE Published → Assess → Triage → Patch → Verify → Close
```

### Patch SLA by CVSS Score
| CVSS Score | Severity | Patch SLA | Emergency patch criteria |
|------------|----------|-----------|--------------------------|
| 9.0 - 10.0 | Critical | 24 hours | If actively exploited: 4 hours |
| 7.0 - 8.9 | High | 7 days | If PoC available: 48 hours |
| 4.0 - 6.9 | Medium | 30 days | - |
| 0.1 - 3.9 | Low | 90 days | - |

```python
def assess_cve(cve_id: str, cvss: float, component: str) -> dict:
    """Triage a CVE against production inventory."""
    # 1. Is the vulnerable component in use?
    affected_services = inventory.find_services_using(component)
    if not affected_services:
        return {"action": "monitor", "reason": "not in production inventory"}

    # 2. Is the vulnerable code path reachable?
    # (Often CVSS assumes worst case; actual risk may be lower)
    reachability = assess_reachability(component, cve_id)

    # 3. Determine priority
    if cvss >= 9.0 or (cvss >= 7.0 and reachability == "direct"):
        priority = "P1"
        sla_hours = 24
    elif cvss >= 7.0:
        priority = "P2"
        sla_hours = 168  # 7 days
    else:
        priority = "P3"
        sla_hours = 720  # 30 days

    return {
        "cve": cve_id, "cvss": cvss, "priority": priority,
        "patch_by": datetime.utcnow() + timedelta(hours=sla_hours),
        "affected_services": affected_services
    }
```

---

## Vulnerability Disclosure Policy Template

```markdown
# Security Vulnerability Disclosure Policy

## Scope
We accept vulnerability reports for: app.mycompany.com, api.mycompany.com,
and any *.mycompany.com subdomain.

Out of scope: Third-party services, social engineering, physical attacks,
automated scan results without exploitation evidence.

## Reporting
Submit reports to: security@mycompany.com
PGP key: [link to public key]

## What to Include
- Description of the vulnerability
- Steps to reproduce
- Potential impact assessment
- Any relevant screenshots or PoC (non-destructive)

## Our Commitments
- Acknowledgment within 48 hours
- Status updates every 7 days
- Remediation within our patch SLA (see above)
- Credit in our security hall of fame (with permission)
- Safe harbor: we will not take legal action against good-faith researchers

## What We Ask
- Do not access or modify customer data
- Do not perform DoS or disruptive testing
- Do not disclose publicly until we have patched (90-day coordinated disclosure)
```

---

## Post-Mortem Structure

```markdown
# Security Incident Post-Mortem

**Incident**: [Brief title]
**Severity**: P0/P1/P2/P3
**Date/Time**: [Start] → [End] (Duration: Xh Ym)
**Author**: [Name]
**Reviewers**: [Names]

## Summary
2-3 sentences: what happened, how it was detected, what was impacted.

## Timeline (UTC)
- HH:MM — First anomalous event detected
- HH:MM — Alert fired / human noticed
- HH:MM — Incident declared
- HH:MM — Root cause identified
- HH:MM — Containment completed
- HH:MM — Service restored / incident resolved

## Root Cause Analysis (5 Whys)
1. Why did the breach occur? → Unpatched CVE in dependency X
2. Why wasn't it patched? → No automated dependency scanning in CI
3. Why no scanning? → Not prioritized in backlog
4. Why not prioritized? → No policy for dependency update SLAs
5. Why no policy? → Security ownership unclear in team

## Impact Assessment
- Users affected: [N users]
- Data exposed: [categories, not contents]
- Financial: [if applicable]
- Regulatory: [GDPR/PCI/HIPAA breach notification required? Yes/No]

## What Went Well
- ...

## What Went Wrong
- ...

## Action Items
| Action | Owner | Due Date | Priority |
|--------|-------|----------|----------|
| Add Snyk to CI pipeline | @engineer | 2025-01-15 | P0 |
| Document patch SLA policy | @security | 2025-01-20 | P1 |
```

---

## Incident Response Checklist

- [ ] Incident commander assigned
- [ ] Severity/priority assessed (P0-P3)
- [ ] Affected systems identified and isolated
- [ ] Evidence preserved before remediation
- [ ] Audit logs pulled for forensic timeline
- [ ] Root cause identified
- [ ] Regulatory notification requirement assessed
- [ ] Affected users/customers notified (if applicable)
- [ ] Vulnerability remediated and verified
- [ ] Post-mortem scheduled within 5 business days
- [ ] Action items with owners and due dates
- [ ] Detection/response improvements in backlog
