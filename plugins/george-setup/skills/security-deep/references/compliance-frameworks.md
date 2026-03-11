# Compliance Frameworks Reference

---

## SOC 2 Type II — Technical Controls

SOC 2 Type II audits operational effectiveness of controls over a period (typically 6-12 months). Trust Service Criteria (TSC) most relevant to engineering:

### CC6 — Logical and Physical Access Controls

```python
# CC6.1 — Restrict logical access to systems
# Implementation: Role-based access with least privilege

# CC6.2 — Register/deregister users (access provisioning)
# Implementation: Automated provisioning with audit trail
def provision_user_access(user_id: str, role: str, granted_by: str):
    db.create_access_grant(user_id=user_id, role=role)
    audit_log.record(
        event="access_granted",
        subject=user_id,
        role=role,
        granted_by=granted_by,
        timestamp=datetime.utcnow()
    )

# CC6.3 — Identification and authentication mechanisms
# Implementation: MFA required for all admin access
# Evidence: Auth logs showing MFA usage rate

# CC6.6 — Restrict access to infrastructure
# Implementation: VPN/bastion host for SSH; no direct internet access
# Evidence: Security groups / firewall rules limiting port 22 to VPN CIDR

# CC6.7 — Restrict transmission of confidential information
# Implementation: TLS 1.2+ everywhere; encryption at rest for PII
# Evidence: TLS scan results; encryption attestations from cloud providers

# CC6.8 — Prevent unauthorized code changes
# Implementation: PR reviews required; branch protection; signed commits
# Evidence: GitHub branch protection rules; commit signing policy
```

### CC7 — System Operations

```python
# CC7.1 — Detect and monitor for new vulnerabilities
# Implementation: Dependabot + Snyk; weekly CVE digest
# Evidence: Vulnerability scan reports; remediation tickets with SLAs

# CC7.2 — Monitor system components
# Implementation: CloudWatch/Datadog alerts; anomaly detection
ALERT_THRESHOLDS = {
    "error_rate_pct": 1.0,     # alert if >1% errors
    "p99_latency_ms": 2000,    # alert if p99 > 2s
    "failed_logins_per_min": 20,  # brute force detection
    "data_export_volume_mb": 100  # unusual data access
}

# CC7.3 — Evaluate security events
# Implementation: SIEM with auto-triage rules
# Evidence: Security incident log; false positive rate

# CC7.4 — Respond to security incidents
# Implementation: Incident response runbook (see incident-response.md)
# Evidence: IR tickets; post-mortems

# CC7.5 — Identify and assess impact of security incidents
# Classification matrix — required for SOC2 evidence:
INCIDENT_CLASSES = {
    "P0": "Customer data breach or unauthorized access",
    "P1": "Service outage affecting security controls",
    "P2": "Vulnerability with active exploitation risk",
    "P3": "Policy violation, no immediate risk"
}
```

### CC8 — Change Management

```python
# CC8.1 — Authorized, tested, and approved changes
# Implementation: PR required for all production changes
# Evidence: GitHub PR history showing: author, reviewer, CI passing, approval

# Change control checklist (automated via PR template):
CHANGE_CHECKLIST = """
- [ ] Security review completed (if touching auth/data/crypto)
- [ ] Tests passing in CI
- [ ] Rollback plan documented
- [ ] Dependent services notified
- [ ] Post-deploy monitoring plan
"""
```

**SOC 2 evidence collection automation**:
```python
# Generate access review report monthly (CC6.2 evidence)
def generate_access_review():
    users = db.get_all_users_with_roles()
    over_provisioned = [u for u in users if not u.last_login_within_90_days]
    return {
        "date": date.today().isoformat(),
        "total_users": len(users),
        "over_provisioned": len(over_provisioned),  # flag for review
        "mfa_enabled_pct": sum(u.mfa_enabled for u in users) / len(users) * 100
    }
```

---

## GDPR — Technical Requirements

### Data Minimization
```python
# Collect only what's needed
class UserRegistration(BaseModel):
    email: str
    password: str
    # Do NOT collect: DOB, phone, address unless functionally necessary

# Minimize data returned in API responses
class UserPublicProfile(BaseModel):
    username: str
    avatar_url: Optional[str]
    joined_date: date
    # Do NOT expose: email, internal IDs, IP addresses
```

### Encryption at Rest and in Transit
```python
# At rest: field-level encryption for PII
from cryptography.fernet import Fernet

FIELD_ENCRYPTION_KEY = Fernet(os.environ["FIELD_ENC_KEY"])

class User(Base):
    __tablename__ = "users"
    id = Column(UUID, primary_key=True)
    _email_encrypted = Column("email", LargeBinary)

    @property
    def email(self) -> str:
        return FIELD_ENCRYPTION_KEY.decrypt(self._email_encrypted).decode()

    @email.setter
    def email(self, value: str):
        self._email_encrypted = FIELD_ENCRYPTION_KEY.encrypt(value.encode())
```

### Right to Erasure (Article 17)
```python
def handle_erasure_request(user_id: str, verified_by: str):
    """GDPR Article 17 — right to erasure."""
    # 1. Pseudonymize rather than hard-delete if needed for audit trail
    user = db.get_user(user_id)
    pseudonym = f"deleted_user_{hashlib.sha256(user_id.encode()).hexdigest()[:8]}"

    db.update_user(user_id, {
        "email": f"{pseudonym}@deleted.invalid",
        "name": "Deleted User",
        "phone": None,
        "address": None,
        "deleted_at": datetime.utcnow(),
        "deletion_reason": "erasure_request"
    })

    # 2. Delete from third-party systems
    analytics.delete_user_data(user_id)
    email_service.unsubscribe(user.email)
    payment_processor.delete_customer(user.payment_customer_id)

    # 3. Log for audit (no PII in the log)
    audit_log.record(event="erasure_completed", user_pseudonym=pseudonym,
                     verified_by=verified_by, completed_at=datetime.utcnow())
```

### Breach Notification (Article 33 — 72 hours)
```python
# Automated breach detection trigger
def detect_data_breach(event: SecurityEvent):
    if event.severity >= "HIGH" and event.involves_personal_data:
        breach_tracker.open_case(
            event_id=event.id,
            detection_time=datetime.utcnow(),
            deadline_72h=datetime.utcnow() + timedelta(hours=72),
            notified_dpa=False,  # Data Protection Authority
            affected_users=event.estimated_affected_count
        )
        # Alert DPO (Data Protection Officer) immediately
        notify_dpo(event)
```

---

## PCI-DSS — Technical Safeguards

### Tokenization (replaces card data with tokens)
```python
# Never store card numbers — use payment processor's vault
import stripe

def process_payment(card_data: dict, amount: int) -> dict:
    # Tokenize client-side (Stripe Elements, Braintree Drop-in)
    # Server only receives a token, never raw card data
    payment_method = stripe.PaymentMethod.create(
        type="card",
        card={"token": card_data["token"]}  # tokenized by Stripe.js
    )
    charge = stripe.PaymentIntent.create(
        amount=amount,
        currency="usd",
        payment_method=payment_method.id,
        confirm=True
    )
    # Store only: last4, card brand, exp_month, exp_year, payment_method_id
    # NEVER store: full card number (PAN), CVV, PIN
    return {"payment_id": charge.id, "last4": payment_method.card.last4}
```

### Network Segmentation (PCI Requirement 1)
```yaml
# Cardholder Data Environment (CDE) must be isolated
# AWS VPC example:
VPC:
  CIDRBlock: 10.0.0.0/16
  Subnets:
    cde-private:   10.0.1.0/24  # payment services — no internet access
    app-private:   10.0.2.0/24  # application tier
    public:        10.0.3.0/24  # load balancers only
  SecurityGroups:
    cde-sg:
      Ingress: only from app-private on port 8443
      Egress: only to payment processor IPs (Stripe: 35.195.0.0/16)
```

### Logging Requirements (PCI Requirement 10)
```python
PCI_REQUIRED_EVENTS = [
    "user_access_to_cardholder_data",
    "admin_action",
    "invalid_logical_access_attempt",
    "use_of_privileged_accounts",
    "initialization_of_audit_logs",
    "creation_deletion_of_objects",
    "failed_access_attempts"
]
# Retain logs: 12 months; 3 months immediately available
# Log integrity: write-once storage (AWS CloudWatch Log Groups with retention)
```

---

## HIPAA — Technical Safeguards

```python
# PHI (Protected Health Information) handling
PHI_FIELDS = {"ssn", "dob", "diagnosis", "medication", "insurance_id", "address"}

class PHIHandler:
    def log_access(self, user_id: str, patient_id: str, fields_accessed: set,
                   purpose: str):
        """HIPAA requires audit log of all PHI access."""
        hipaa_audit_log.record({
            "timestamp": datetime.utcnow().isoformat(),
            "user": user_id,
            "patient": patient_id,
            "fields": list(fields_accessed & PHI_FIELDS),
            "purpose": purpose,  # treatment, payment, operations
            "access_type": "read"
        })

    def minimum_necessary(self, record: dict, user_role: str) -> dict:
        """HIPAA minimum necessary rule — only expose needed fields."""
        ROLE_FIELDS = {
            "billing": {"dob", "insurance_id", "diagnosis_code"},
            "nurse": {"dob", "diagnosis", "medication", "allergies"},
            "admin": PHI_FIELDS
        }
        allowed = ROLE_FIELDS.get(user_role, set())
        return {k: v for k, v in record.items() if k in allowed or k not in PHI_FIELDS}
```

---

## ISO 27001 — Key Controls for Developers

| Control | ID | Implementation |
|---------|-----|----------------|
| Cryptographic policy | A.8.24 | Document approved algorithms; prohibit MD5/DES |
| Access control | A.5.15 | RBAC; quarterly access reviews |
| Secure development | A.8.25 | SSDLC; security training; code review |
| Protection from malware | A.8.7 | Dependency scanning; container scanning |
| Vulnerability management | A.8.8 | CVE tracking; SLA for patch deployment |
| Logging and monitoring | A.8.15 | Structured audit logs; SIEM |
| Supplier relationships | A.5.20 | Third-party security assessments; SLAs |
| Incident management | A.5.26 | IR runbook; post-mortems |

---

## Compliance Automation Tools

### Vanta
- Continuously monitors: AWS config, GitHub security, Okta MFA compliance
- Integrates with: Jira (auto-creates remediation tasks), Slack alerts
- Evidence collection: automatic screenshots + API data for auditors

### Drata
- Similar to Vanta; strong compliance mapping
- Automated employee security training tracking
- Real-time compliance score dashboard

### Self-service compliance checklist
```bash
# Run before SOC2 audit
# 1. MFA enabled for all users
aws iam generate-credential-report && aws iam get-credential-report

# 2. All S3 buckets encrypted
aws s3api list-buckets | jq -r '.Buckets[].Name' | \
  xargs -I{} aws s3api get-bucket-encryption --bucket {}

# 3. All RDS encrypted at rest
aws rds describe-db-instances | jq '.DBInstances[] | {id: .DBInstanceIdentifier, encrypted: .StorageEncrypted}'

# 4. CloudTrail enabled in all regions
aws cloudtrail describe-trails --include-shadow-trails

# 5. GuardDuty enabled
aws guardduty list-detectors
```

---

## Compliance Checklist by Standard

**SOC 2**
- [ ] MFA on all admin/production accounts
- [ ] Quarterly access reviews documented
- [ ] Change management: all changes via reviewed PRs
- [ ] Vulnerability scan reports with remediation evidence
- [ ] Security incident log with response times

**GDPR**
- [ ] Privacy policy current and accessible
- [ ] Data processing register maintained
- [ ] Erasure request workflow implemented
- [ ] Breach notification procedure (72-hour SLA)
- [ ] DPA agreements with all sub-processors

**PCI-DSS**
- [ ] No card data stored (tokenization)
- [ ] CDE network segmented
- [ ] WAF in front of cardholder-related endpoints
- [ ] Penetration test annually
- [ ] Audit logs retained 12 months

**HIPAA**
- [ ] PHI encrypted at rest and in transit
- [ ] Minimum-necessary access enforced
- [ ] PHI access audit log
- [ ] BAAs signed with all business associates
- [ ] Workforce training annually
