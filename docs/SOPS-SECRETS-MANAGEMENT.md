# SOPS Secrets Management

**Date:** 2025-10-24
**Status:** Implemented - Phase 2.4
**Encryption:** age (File encryption tool)

## Overview

This repository uses **SOPS** (Secrets OPerationS) with **age** encryption to securely store secrets in Git. All sensitive data is encrypted before being committed, allowing safe GitOps workflows.

## Architecture

```
┌─────────────┐     ┌──────────┐     ┌──────────┐     ┌─────────┐
│   Developer │────▶│   SOPS   │────▶│   Git    │────▶│ Argo CD │
│             │     │ Encrypt  │     │ (safe)   │     │ Decrypt │
└─────────────┘     └──────────┘     └──────────┘     └─────────┘
                         ↓                                   ↓
                    age public                          age private
                       key                                 key
```

## Key Features

✅ **Encrypted at rest**: All secrets encrypted with AES256-GCM
✅ **Git-safe**: Encrypted secrets can be committed to Git
✅ **GitOps compatible**: Argo CD automatically decrypts on deployment
✅ **Age encryption**: Modern, secure file encryption
✅ **Selective encryption**: Only values encrypted, structure visible
✅ **Audit trail**: Full Git history of secret changes

## Installation

### 1. Install Tools

**macOS:**
```bash
brew install sops age
```

**Linux:**
```bash
# SOPS
curl -LO https://github.com/getsops/sops/releases/download/v3.11.0/sops-v3.11.0.linux.amd64
chmod +x sops-v3.11.0.linux.amd64
sudo mv sops-v3.11.0.linux.amd64 /usr/local/bin/sops

# age
curl -LO https://github.com/FiloSottile/age/releases/download/v1.2.1/age-v1.2.1-linux-amd64.tar.gz
tar xzf age-v1.2.1-linux-amd64.tar.gz
sudo mv age/age age/age-keygen /usr/local/bin/
```

### 2. Verify Installation

```bash
sops --version  # Should show v3.11.0
age --version   # Should show v1.2.1
```

## Configuration

### Age Keys

**Location:** `.secrets/keys/age-yc-dev.txt` (gitignored)

**Public Key:** `age175lvx7gs4mxxe825phgenduucdx9rah4df8pdswngxe4el38jejsp2grhj`

⚠️ **Private keys are NEVER committed to Git**

### SOPS Configuration

**File:** `.sops.yaml`

```yaml
creation_rules:
  # YC Dev cluster secrets
  - path_regex: clusters/yc-dev/.*secrets.*\.yaml$
    age: age175lvx7gs4mxxe825phgenduucdx9rah4df8pdswngxe4el38jejsp2grhj

  # Development environment app secrets
  - path_regex: apps/.*/overlays/dev/secrets.*\.yaml$
    age: age175lvx7gs4mxxe825phgenduucdx9rah4df8pdswngxe4el38jejsp2grhj
```

## Usage

### Encrypting Secrets

**1. Create unencrypted secret:**

```yaml
# apps/webapp/overlays/dev/secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: webapp-secrets
  namespace: dev
type: Opaque
stringData:
  DB_PASSWORD: "my-secret-password"
  API_KEY: "sk_live_1234567890"
```

**2. Encrypt with SOPS:**

```bash
# Set age key file location
export SOPS_AGE_KEY_FILE=.secrets/keys/age-yc-dev.txt

# Encrypt
sops -e apps/webapp/overlays/dev/secrets.yaml > apps/webapp/overlays/dev/secrets.enc.yaml

# Remove unencrypted file
rm apps/webapp/overlays/dev/secrets.yaml
```

**3. Encrypted result:**

```yaml
apiVersion: ENC[AES256_GCM,data:3gw=,iv:...,tag:...,type:str]
kind: ENC[AES256_GCM,data:z+Zk+iUK,iv:...,tag:...,type:str]
stringData:
    DB_PASSWORD: ENC[AES256_GCM,data:6tHJdscJ...,iv:...,tag:...,type:str]
    API_KEY: ENC[AES256_GCM,data:FRgkxdXh...,iv:...,tag:...,type:str]
sops:
    age:
        - recipient: age175lvx7gs4mxxe825phgenduucdx9rah4df8pdswngxe4el38jejsp2grhj
          enc: |
            -----BEGIN AGE ENCRYPTED FILE-----
            ...
            -----END AGE ENCRYPTED FILE-----
```

### Decrypting Secrets

**View decrypted content:**

```bash
export SOPS_AGE_KEY_FILE=.secrets/keys/age-yc-dev.txt
sops -d apps/webapp/overlays/dev/secrets.enc.yaml
```

**Edit encrypted file:**

```bash
# Opens in editor, automatically decrypts and re-encrypts on save
sops apps/webapp/overlays/dev/secrets.enc.yaml
```

**Extract specific value:**

```bash
sops -d --extract '["stringData"]["DB_PASSWORD"]' apps/webapp/overlays/dev/secrets.enc.yaml
```

## Argo CD Integration

### Setup

**1. Create Kubernetes Secret with age key:**

```bash
# In Argo CD namespace
kubectl create secret generic sops-age \
  --from-file=keys.txt=.secrets/keys/age-yc-dev.txt \
  -n argocd
```

**2. Configure Argo CD to use SOPS:**

Argo CD v2.11+ has built-in SOPS support via ConfigMap:

```yaml
# clusters/yc-dev/argo-cd/argocd-cm-patch.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  kustomize.buildOptions: --enable-alpha-plugins --enable-helm
  # Enable SOPS decryption
  helm.valuesFileSchemes: >-
    secrets+gpg-import, secrets+gpg-import-kubernetes,
    secrets+age-import, secrets+age-import-kubernetes,
    secrets, https
```

**3. Configure Application to use SOPS:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: webapp-dev
spec:
  source:
    # SOPS will automatically decrypt .enc.yaml files
    helm:
      valuesObject:
        sops:
          age:
            secretName: sops-age
```

### How It Works

1. Developer encrypts secret with SOPS locally
2. Encrypted `.enc.yaml` committed to Git
3. Argo CD pulls encrypted file
4. Argo CD uses age private key from Kubernetes Secret
5. SOPS automatically decrypts during manifest rendering
6. Decrypted secret deployed to cluster

## Security Best Practices

### ✅ DO

- ✅ Keep private keys in `.secrets/` (gitignored)
- ✅ Use different keys per environment (dev/staging/prod)
- ✅ Rotate keys periodically (every 90 days)
- ✅ Store private keys in team password manager (1Password/Bitwarden)
- ✅ Use age keys (modern, secure)
- ✅ Encrypt all sensitive values
- ✅ Review encrypted files before committing

### ❌ DON'T

- ❌ NEVER commit private keys to Git
- ❌ NEVER commit unencrypted secrets
- ❌ DON'T share private keys via chat/email
- ❌ DON'T reuse the same key across projects
- ❌ DON'T forget to encrypt before committing
- ❌ DON'T use weak encryption (KMS better for production)

## File Naming Convention

```
apps/webapp/overlays/dev/
├── secrets.enc.yaml       # ✅ Encrypted (commit this)
└── secrets.yaml           # ❌ Unencrypted (DO NOT commit)
```

**Pattern:** `*secrets*.enc.yaml` - encrypted, safe to commit
**Pattern:** `*secrets*.yaml` - unencrypted, gitignored

## Troubleshooting

### Error: "no matching creation rules found"

**Problem:** SOPS can't find rule in `.sops.yaml` for the file path

**Solution:** Check that file path matches regex in `.sops.yaml`

```bash
# File: apps/webapp/overlays/dev/secrets.yaml
# Regex: apps/.*/overlays/dev/secrets.*\.yaml$  ✅ Matches
```

### Error: "failed to get master key"

**Problem:** Age private key not found or wrong key specified

**Solution:** Set correct age key file path

```bash
export SOPS_AGE_KEY_FILE=.secrets/keys/age-yc-dev.txt
sops -d secrets.enc.yaml
```

### Error: "MAC mismatch"

**Problem:** File was modified outside of SOPS

**Solution:** Re-encrypt the file properly

```bash
# Decrypt, edit, re-encrypt
sops -d secrets.enc.yaml > secrets.yaml
# Edit secrets.yaml manually
sops -e secrets.yaml > secrets.enc.yaml
rm secrets.yaml
```

## Key Rotation

**When to rotate:**
- Every 90 days (recommended)
- When team member leaves
- When key might be compromised
- When moving to production

**How to rotate:**

```bash
# 1. Generate new age key
age-keygen -o .secrets/keys/age-yc-dev-new.txt

# 2. Update .sops.yaml with new public key

# 3. Re-encrypt all secrets
find . -name "*.enc.yaml" -exec sops updatekeys {} \;

# 4. Update Kubernetes secret in cluster
kubectl create secret generic sops-age \
  --from-file=keys.txt=.secrets/keys/age-yc-dev-new.txt \
  -n argocd \
  --dry-run=client -o yaml | kubectl apply -f -

# 5. Test decryption with new key

# 6. Securely delete old key
shred -u .secrets/keys/age-yc-dev.txt
```

## Example: Complete Workflow

```bash
# 1. Setup (once)
brew install sops age
age-keygen -o .secrets/keys/age-yc-dev.txt
export SOPS_AGE_KEY_FILE=.secrets/keys/age-yc-dev.txt

# 2. Create secret
cat > secrets.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: my-app-secrets
  namespace: default
type: Opaque
stringData:
  password: "super-secret-123"
EOF

# 3. Encrypt
sops -e secrets.yaml > secrets.enc.yaml
rm secrets.yaml

# 4. Commit to Git
git add secrets.enc.yaml .sops.yaml
git commit -m "feat: add encrypted secrets"
git push

# 5. Argo CD automatically decrypts and deploys
```

## CI/CD Integration

**GitHub Actions:**

```yaml
- name: Decrypt secrets for testing
  env:
    SOPS_AGE_KEY: ${{ secrets.SOPS_AGE_PRIVATE_KEY }}
  run: |
    echo "$SOPS_AGE_KEY" > /tmp/age-key.txt
    export SOPS_AGE_KEY_FILE=/tmp/age-key.txt
    sops -d secrets.enc.yaml > secrets.yaml
    # Use secrets.yaml in tests
    rm /tmp/age-key.txt secrets.yaml
```

## References

- [SOPS Documentation](https://github.com/getsops/sops)
- [age Documentation](https://github.com/FiloSottile/age)
- [Argo CD SOPS Support](https://argo-cd.readthedocs.io/en/stable/operator-manual/secret-management/)

---

**Document Version:** 1.0
**Last Updated:** 2025-10-24
**Maintained By:** Platform Team
