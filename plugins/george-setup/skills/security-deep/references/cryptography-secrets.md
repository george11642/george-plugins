# Cryptography & Secrets Management Reference

---

## Symmetric Encryption — AES-256-GCM

AES-GCM provides authenticated encryption: confidentiality + integrity + authenticity in one operation.

```python
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
import os

# Key generation (do once, store in KMS/Vault — NEVER in source)
key = os.urandom(32)  # 256-bit

def encrypt(plaintext: bytes, associated_data: bytes = b"") -> bytes:
    """Returns nonce + ciphertext (nonce is prepended for storage)."""
    nonce = os.urandom(12)  # 96-bit nonce — NEVER reuse with same key
    aesgcm = AESGCM(key)
    ciphertext = aesgcm.encrypt(nonce, plaintext, associated_data)
    return nonce + ciphertext  # store together

def decrypt(data: bytes, associated_data: bytes = b"") -> bytes:
    nonce, ciphertext = data[:12], data[12:]
    aesgcm = AESGCM(key)
    return aesgcm.decrypt(nonce, ciphertext, associated_data)
    # Raises InvalidTag if tampered — handle this explicitly
```

**Never use**:
- ECB mode — identical plaintext blocks → identical ciphertext blocks (reveals patterns)
- CBC without MAC — vulnerable to padding oracle attacks
- RC4, DES, 3DES — broken or deprecated

**Nonce rules**: With AES-GCM, nonce reuse with the same key is catastrophic (destroys confidentiality and integrity). Use random 12-byte nonces; if processing >2^32 messages with one key, rotate the key.

---

## Asymmetric Encryption — RSA-OAEP & ECDSA

### RSA-OAEP for encryption
```python
from cryptography.hazmat.primitives.asymmetric import rsa, padding
from cryptography.hazmat.primitives import hashes, serialization

# Key generation
private_key = rsa.generate_private_key(public_exponent=65537, key_size=4096)
public_key = private_key.public_key()

# Encrypt (use public key)
ciphertext = public_key.encrypt(
    plaintext,
    padding.OAEP(
        mgf=padding.MGF1(algorithm=hashes.SHA256()),
        algorithm=hashes.SHA256(),
        label=None
    )
)

# Decrypt (use private key)
plaintext = private_key.decrypt(ciphertext, padding.OAEP(
    mgf=padding.MGF1(algorithm=hashes.SHA256()),
    algorithm=hashes.SHA256(),
    label=None
))
```

**Never use PKCS1v15 for new systems** — vulnerable to Bleichenbacher attack.

### ECDSA for signatures (preferred over RSA for signatures)
```python
from cryptography.hazmat.primitives.asymmetric import ec

private_key = ec.generate_private_key(ec.SECP256R1())
public_key = private_key.public_key()

# Sign
signature = private_key.sign(message, ec.ECDSA(hashes.SHA256()))

# Verify
try:
    public_key.verify(signature, message, ec.ECDSA(hashes.SHA256()))
    # No exception = valid
except Exception:
    # Invalid signature
```

**Curve selection**: P-256 (secp256r1) — widely supported. Ed25519 — faster, simpler, no random needed for signing.

---

## Envelope Encryption

Used by AWS KMS, Google Cloud KMS, HashiCorp Vault. Encrypts data with a Data Encryption Key (DEK), then encrypts the DEK with a Key Encryption Key (KEK) stored in KMS.

```python
# 1. Generate a unique DEK per record/file
dek = os.urandom(32)

# 2. Encrypt data with DEK
encrypted_data = encrypt(plaintext, dek)

# 3. Encrypt DEK with KMS master key
import boto3
kms = boto3.client("kms")
response = kms.encrypt(KeyId="arn:aws:kms:...", Plaintext=dek)
encrypted_dek = response["CiphertextBlob"]

# 4. Store: encrypted_data + encrypted_dek (DEK itself never stored in plaintext)

# Decryption:
# 1. Call KMS to decrypt encrypted_dek → dek
# 2. Use dek to decrypt encrypted_data
```

**Benefits**: Rotate master key without re-encrypting all data; limit KMS API calls.

---

## TLS Configuration

### TLS 1.3 — Nginx
```nginx
server {
    listen 443 ssl;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;  # TLS 1.3 manages its own ciphers
    ssl_session_timeout 1d;
    ssl_session_cache shared:MozSSL:10m;
    ssl_session_tickets off;  # Forward secrecy
    ssl_stapling on;
    ssl_stapling_verify on;
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
}
```

**Disable**: TLS 1.0, TLS 1.1, SSLv3. **Remove**: RC4, 3DES, NULL ciphers, export ciphers, MD5 MACs.

### Certificate pinning (mobile)
```swift
// iOS — URLSession delegate
func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
    guard let serverTrust = challenge.protectionSpace.serverTrust,
          let certificate = SecTrustGetCertificateAtIndex(serverTrust, 0) else {
        completionHandler(.cancelAuthenticationChallenge, nil)
        return
    }
    let serverCertData = SecCertificateCopyData(certificate) as Data
    let pinnedHash = "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" // base64 SPKI hash
    // Compare SPKI hash of certificate
    completionHandler(matches ? .useCredential : .cancelAuthenticationChallenge,
                      matches ? URLCredential(trust: serverTrust) : nil)
}
```

**Pinning warning**: Pin to SPKI (Subject Public Key Info) hash, not certificate. Pin backup key too. Have rotation plan.

---

## HashiCorp Vault

### Dynamic secrets — database credentials
```bash
# Enable database secrets engine
vault secrets enable database

# Configure PostgreSQL
vault write database/config/mydb \
    plugin_name=postgresql-database-plugin \
    allowed_roles="readonly,readwrite" \
    connection_url="postgresql://{{username}}:{{password}}@db:5432/myapp?sslmode=require" \
    username="vault" \
    password="vault-password"

# Create role — Vault generates ephemeral credentials with TTL
vault write database/roles/readonly \
    db_name=mydb \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
    default_ttl="1h" \
    max_ttl="24h"

# Application gets creds (rotated automatically):
vault read database/creds/readonly
# lease_id: database/creds/readonly/abc123
# lease_duration: 1h
# username: v-token-abc-xyz
# password: A1a-...
```

### Vault policies (HCL)
```hcl
# Policy: app can only read its own secrets
path "secret/data/myapp/*" {
  capabilities = ["read"]
}
path "database/creds/readonly" {
  capabilities = ["read"]
}
# Deny admin paths
path "sys/*" {
  capabilities = ["deny"]
}
```

### AppRole authentication (for CI/CD)
```bash
vault auth enable approle
vault write auth/approle/role/myapp \
    secret_id_ttl=10m \
    token_num_uses=10 \
    token_ttl=20m \
    token_max_ttl=30m \
    policies="myapp-policy"

# Get credentials
ROLE_ID=$(vault read auth/approle/role/myapp/role-id -format=json | jq -r .data.role_id)
SECRET_ID=$(vault write -f auth/approle/role/myapp/secret-id -format=json | jq -r .data.secret_id)

# Login
vault write auth/approle/login role_id=$ROLE_ID secret_id=$SECRET_ID
```

---

## AWS Secrets Manager

```python
import boto3, json

def get_secret(secret_name: str, region: str = "us-east-1") -> dict:
    client = boto3.client("secretsmanager", region_name=region)
    response = client.get_secret_value(SecretId=secret_name)
    return json.loads(response["SecretString"])

# Automatic rotation — Lambda function rotated every 30 days
# Define rotation lambda in AWS console or via CDK:
import aws_cdk as cdk
from aws_cdk import aws_secretsmanager as sm
secret = sm.Secret(self, "DBSecret",
    generate_secret_string=sm.SecretStringGenerator(
        secret_string_template=json.dumps({"username": "admin"}),
        generate_string_key="password",
        exclude_characters="/@\""
    )
)
secret.add_rotation_schedule("Rotation",
    automatically_after=cdk.Duration.days(30),
    hosted_rotation=sm.HostedRotation.mysql_single_user()
)
```

---

## Environment Variable Anti-Patterns

```bash
# NEVER: secrets in environment variables set in Dockerfiles/source
ENV DATABASE_PASSWORD=mysecret123  # visible in image layers

# NEVER: secrets in docker-compose.yml committed to git
environment:
  - AWS_SECRET_KEY=AKIAIOSFODNN7EXAMPLE

# NEVER: secrets passed as build args
docker build --build-arg API_KEY=secret .

# BETTER: use secret mounts (Docker BuildKit)
RUN --mount=type=secret,id=api_key cat /run/secrets/api_key

# BETTER: use environment injection at runtime from Vault/Secrets Manager
# e.g., via vault agent sidecar, AWS Parameter Store, or envconsul
```

---

## Secret Scanning Tools

### detect-secrets (pre-commit)
```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.5.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']
```

```bash
detect-secrets scan > .secrets.baseline
detect-secrets audit .secrets.baseline
```

### truffleHog — scan git history
```bash
trufflehog git file://. --only-verified
trufflehog github --org=myorg --token=$GITHUB_TOKEN
```

### gitleaks — CI integration
```yaml
- name: Scan for secrets
  uses: gitleaks/gitleaks-action@v2
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    GITLEAKS_LICENSE: ${{ secrets.GITLEAKS_LICENSE }}
```

---

## Key Management Lifecycle

```
Generate → Store → Distribute → Use → Rotate → Revoke → Destroy
```

| Phase | Best Practice |
|-------|---------------|
| Generate | Use hardware RNG (OS urandom, HSM) |
| Store | KMS or Vault — never plaintext on disk |
| Distribute | Short-lived tokens, env injection at runtime |
| Use | Least-privilege policies; audit all access |
| Rotate | Automated; overlap period for in-flight operations |
| Revoke | Immediate; propagate to all services within minutes |
| Destroy | Cryptographic erasure; audit trail |

**Key rotation schedule**: Symmetric keys: 1 year max. Signing keys: 2 years. TLS certs: 90 days (Let's Encrypt) or 1 year. API keys: 90 days or on-demand.

---

## Cryptography Checklist

- [ ] AES-256-GCM for symmetric encryption (random nonce, never reuse)
- [ ] argon2id/bcrypt for password hashing (never MD5/SHA alone)
- [ ] RS256 or ES256 for JWT (not HS256 for multi-service)
- [ ] RSA-OAEP for asymmetric encryption (not PKCS1v15)
- [ ] TLS 1.2+ only; 1.3 preferred; strong cipher suites
- [ ] Certificates rotated before expiry (automated via ACME/cert-manager)
- [ ] Secrets in Vault/KMS, not environment variables or source code
- [ ] Secret scanning in pre-commit hooks and CI
- [ ] Key rotation policy documented and automated
- [ ] Envelope encryption for bulk data
