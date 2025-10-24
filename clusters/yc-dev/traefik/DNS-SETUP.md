# DNS Configuration for Traefik Ingress

## External IP

**Traefik LoadBalancer IP:** `158.160.198.44`

## DNS Records to Create

Add the following A record to your DNS provider (e.g., Cloudflare, Route53, etc.):

```
Type: A
Name: argocd.dev.tulupov.org
Value: 158.160.198.44
TTL: 300 (or Auto)
```

### Alternative DNS Records

If you want all dev subdomains to point to the same IP, you can use a wildcard:

```
Type: A
Name: *.dev.tulupov.org
Value: 158.160.198.44
TTL: 300
```

This will route:
- `argocd.dev.tulupov.org` → 158.160.198.44
- `grafana.dev.tulupov.org` → 158.160.198.44
- `*.dev.tulupov.org` → 158.160.198.44

## Verify DNS Propagation

After adding the DNS record, verify it has propagated:

```bash
# Check DNS resolution
nslookup argocd.dev.tulupov.org

# Or using dig
dig argocd.dev.tulupov.org

# Expected output should show:
# argocd.dev.tulupov.org. 300 IN A 158.160.198.44
```

## Access Argo CD

Once DNS is configured, access Argo CD at:

**URL:** https://argocd.dev.tulupov.org

**Credentials:**
- Username: `admin`
- Password: `CF9A68TAQ0013y5Y`

## Notes

- DNS propagation typically takes 1-15 minutes
- If using self-signed TLS, your browser will show a security warning (expected until cert-manager is configured)
- For production, we'll add cert-manager with Let's Encrypt for automatic TLS certificates

## Next Steps

1. Configure DNS record in your provider
2. Wait for DNS propagation
3. Access https://argocd.dev.tulupov.org
4. (Optional) Set up cert-manager for automatic TLS with Let's Encrypt
