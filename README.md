# AWS Cognito SAML Azure AD Integration Demo

This Terraform configuration demonstrates how to set up AWS Cognito with Azure AD as a SAML identity provider, including a static website demo application.

## Architecture

- **AWS Cognito User Pool**: Manages user authentication and federation
- **Azure AD SAML Provider**: Configured as a SAML identity provider in Cognito
- **Cognito Hosted UI**: Provides the login interface
- **S3 Static Website**: Demo application hosted on S3 with CloudFront HTTPS
- **CloudFront Distribution**: Provides HTTPS access to the static website

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate credentials
- Azure AD tenant with an app registration (Enterprise Application for SAML)
- Azure AD admin access to configure SAML SSO settings
- No client secret required (SAML uses certificates from metadata)

## Setup Instructions

### 1. Azure AD App Registration

Before deploying, you need to create an app registration in Azure AD:

1. Go to Azure Portal → Azure Active Directory → App registrations
2. Create a new registration
3. Note down:
   - **Tenant ID** (from Azure AD overview)
   - **Application (client) ID**

### 2. Configure Terraform Variables

Create a `terraform.tfvars` file:

```hcl
azure_tenant_id = "your-azure-tenant-id"
azure_client_id = "your-azure-client-id"
```

**Note**: The AWS region is automatically detected from your AWS credentials/config. You can override it by setting the `AWS_REGION` environment variable or configuring it in your AWS CLI config.

### 3. Deploy Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

### 4. Configure Azure AD Enterprise Application (SAML)

After deployment, you need to configure Azure AD as an Enterprise Application with SAML SSO:

1. **Get the configuration values:**

   ```bash
   terraform output entity_id     # Identifier (Entity ID)
   terraform output redirect_uri   # Reply URL (Assertion Consumer Service URL)
   ```

2. **In Azure Portal:**
   - Go to **Microsoft Entra ID** → **Enterprise applications**
   - Find your application (or create one if it doesn't exist)
   - Click on the application → **Single sign-on** → **SAML**

3. **Configure SAML settings:**
   - **Identifier (Entity ID)**: Use the value from `terraform output entity_id`
     - Example: `urn:amazon:cognito:sp:ap-southeast-2_DMak8IXtc`
   - **Reply URL (Assertion Consumer Service URL)**: Use the value from `terraform output redirect_uri`
     - Example: `https://azure-demo-38cf01f4.auth.ap-southeast-2.amazoncognito.com/saml2/idpresponse`
   - Click **Save**

4. **Configure Attribute Mapping (if needed):**
   - Ensure email claim is mapped: `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress`

**Note:** This is different from App Registration. For SAML, you configure it as an Enterprise Application, not in App Registration.

### 5. Test the Demo Website

The demo website automatically has the Cognito configuration injected when deployed via Terraform. If you're using the S3 website, it should work out of the box.

If you need to configure it manually (e.g., for local testing), you can either:

#### Option A: Manual Configuration

1. Open the website (from `terraform output website_url`)
2. Click "Configure Cognito" button
3. Enter:

   - Cognito domain (from `terraform output cognito_domain`)
   - Client ID (from `terraform output app_client_id`)
   - AWS region

#### Option B: URL Parameters

Access the website with query parameters:

```text
https://<website-url>?cognito_domain=<domain>&client_id=<client-id>&region=<region>
```

## Outputs

After deployment, Terraform will output:

- `cognito_domain`: Cognito hosted UI domain name
- `user_pool_id`: Cognito User Pool ID
- `app_client_id`: Application Client ID
- `entity_id`: SAML Entity ID (Identifier) to configure in Azure AD
- `redirect_uri`: SAML Reply URL (Assertion Consumer Service URL) to configure in Azure AD
- `website_url`: CloudFront HTTPS website URL (use this for OAuth callbacks)
- `website_domain`: CloudFront domain name
- `s3_bucket_name`: S3 bucket name (for reference)

## Testing Guide

### Step 1: Deploy Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

After deployment, note the outputs:

- `entity_id` - SAML Entity ID to configure in Azure AD Enterprise Application
- `redirect_uri` - SAML Reply URL to configure in Azure AD Enterprise Application
- `website_url` - CloudFront HTTPS website URL

### Step 2: Configure Azure AD Enterprise Application (SAML)

1. **Get the configuration values:**

   ```bash
   terraform output entity_id     # Identifier (Entity ID)
   terraform output redirect_uri   # Reply URL (Assertion Consumer Service URL)
   ```

2. **In Azure Portal:**
   - Go to **Microsoft Entra ID** → **Enterprise applications**
   - Find your application (or create one from your App Registration)
   - Click on the application → **Single sign-on** → **SAML**

3. **Configure SAML settings:**
   - **Identifier (Entity ID)**: Use the value from `terraform output entity_id`
   - **Reply URL (Assertion Consumer Service URL)**: Use the value from `terraform output redirect_uri`
   - Click **Save**

4. **Configure Attribute Mapping (if needed):**
   - Ensure email claim is mapped: `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress`

### Step 3: Test the Website

1. **Get the website URL:**

   ```bash
   terraform output website_url
   ```

2. **Open the URL in your browser:**
   - The website should load over HTTPS (CloudFront provides HTTPS)
   - The Cognito configuration is automatically injected from Terraform

3. **Test the Login Flow:**
   - Click "Login with Azure AD"
   - You'll be redirected to Cognito, then to Azure AD (SAML SSO)
   - Sign in with your Azure AD credentials
   - After authentication, Azure AD sends SAML assertion to Cognito
   - Cognito processes it and redirects back to your app with OAuth tokens

### Step 4: Verify the Flow

1. **Click "Login with Azure AD"** → Redirects to Cognito → Then to Azure AD (SAML SSO)
2. **Sign in** → Authenticates with Azure AD
3. **SAML assertion** → Azure AD sends SAML assertion to Cognito
4. **Redirect back** → Cognito processes SAML and redirects to app with authorization code
5. **Token exchange** → App exchanges code for tokens (using PKCE)
6. **User info displayed** → Should show:
   - Name
   - Email
   - Given Name
   - Family Name
   - Token expiration

### Testing Checklist

- [ ] Infrastructure deployed successfully
- [ ] Azure AD Enterprise Application configured with SAML SSO
- [ ] Entity ID configured in Azure AD
- [ ] Reply URL configured in Azure AD
- [ ] Can access website over HTTPS
- [ ] Login redirects to Azure AD
- [ ] Can authenticate with Azure AD
- [ ] SAML assertion processed by Cognito
- [ ] Redirects back to app
- [ ] Authorization code exchanged for tokens
- [ ] User information displays correctly
- [ ] Logout works

## Using the Demo

1. Open the website URL from the outputs (or localhost:5173 for testing)
2. Click "Login with Azure AD"
3. You'll be redirected to Azure AD login
4. After authentication, you'll be redirected back with your user information displayed

## How It Works

1. **User clicks login** → Redirected to Cognito OAuth endpoint
2. **Cognito initiates SAML** → Redirects to Azure AD with SAML request
3. **User authenticates** → Azure AD validates credentials
4. **Azure AD sends SAML assertion** → To Cognito `/saml2/idpresponse` endpoint
5. **Cognito processes SAML** → Creates/updates user and generates OAuth tokens
6. **Cognito redirects to app** → With authorization code (using PKCE)
7. **App exchanges code** → For ID token and access token
8. **Application displays** → User information from ID token

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

## Variables

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `azure_tenant_id` | Azure AD tenant ID | `string` | - | Yes |
| `azure_client_id` | Azure AD application client ID | `string` | - | Yes |

## Notes

- **SAML vs OIDC**: This demo uses SAML for Azure AD integration (simpler, no client secret needed)
- **Authorization Code Flow with PKCE**: The app uses OAuth 2.0 authorization code flow with PKCE for secure token exchange (no backend required)
- **CloudFront HTTPS**: The S3 website is served via CloudFront with HTTPS (required for OAuth callbacks)
- **Client Secret**: Not needed with SAML - Cognito uses certificates from Azure AD metadata
- **S3 Bucket**: Private access (only accessible via CloudFront OAC)
- **Cognito Domain**: Uses a random suffix to ensure uniqueness
- **Email**: Auto-verified in the user pool
- **Identity Provider**: Only Azure AD SAML is enabled (no Cognito username/password)

## Troubleshooting

**Issue**: `AADSTS700016: Application with identifier 'urn:amazon:cognito:sp:...' was not found`

- **Solution**: This means Azure AD doesn't recognize the Entity ID. Configure the Enterprise Application in Azure AD:
  - Go to **Microsoft Entra ID** → **Enterprise applications** → Your app → **Single sign-on** → **SAML**
  - Set **Identifier (Entity ID)** to the value from `terraform output entity_id`
  - Set **Reply URL** to the value from `terraform output redirect_uri`
  - Click **Save**

**Issue**: "Invalid redirect URI" error

- **Solution**: Ensure the Reply URL in Azure AD Enterprise Application SAML settings matches exactly the output from `terraform output redirect_uri`

**Issue**: Website shows "Cognito configuration not found"

- **Solution**: The configuration is automatically injected. If it doesn't appear, check that the S3 object was uploaded correctly.

**Issue**: Authentication succeeds but user info not displayed

- **Solution**: Check that the SAML attribute mapping includes email claim. The email should be mapped to `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress`

**Issue**: SAML certificate errors

- **Solution**: Cognito automatically fetches the certificate from the metadata URL. No manual certificate configuration needed when using `MetadataURL`.

## License

See LICENSE file for details.
