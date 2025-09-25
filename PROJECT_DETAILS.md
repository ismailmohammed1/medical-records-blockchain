# Medical Records Blockchain Platform - Technical Details

## Contract Architecture

The medical records blockchain platform is implemented as a single comprehensive Clarity smart contract (`health-records.clar`) with 361 lines of code, providing a complete healthcare data management system.

## Core Data Structures

### Patient Data Maps
- `patients`: Core patient information with encrypted personal data
- `patient-by-principal`: Reverse lookup for patients by blockchain address
- `patient-records`: Index of medical record IDs per patient

### Provider Data Maps
- `healthcare-providers`: Provider registration and verification data
- `provider-by-principal`: Reverse lookup for providers by blockchain address

### Access Control Maps
- `patient-provider-permissions`: Access control matrix for patient-provider relationships

## Smart Contract Functions Summary

### Public Functions (15)
1. `register-patient` - Patient registration
2. `update-patient-info` - Patient information updates
3. `register-provider` - Healthcare provider registration
4. `verify-provider` - Admin provider verification
5. `create-medical-record` - Medical record creation
6. `archive-record` - Record archival
7. `grant-provider-access` - Grant provider access
8. `revoke-provider-access` - Revoke provider access
9. `toggle-emergency-mode` - Emergency mode control

### Read-Only Functions (6)
1. `get-patient-records` - Retrieve patient's record IDs
2. `get-medical-record` - Retrieve specific medical record
3. `get-patient-info` - Get patient information
4. `get-provider-info` - Get provider information
5. `get-access-permissions` - View access permissions
6. `get-contract-stats` - Contract statistics

## Security Features

### Access Control Levels
- Level 1: Read access only
- Level 2: Read and write access
- Level 3: Full access (read, write, admin)

### Privacy Levels
- Level 1: Private (minimal sharing)
- Level 2: Limited sharing
- Level 3: Open sharing (with consent)

### Error Handling
The contract includes 8 comprehensive error codes:
- `err-owner-only` (100): Admin-only function access
- `err-not-found` (101): Resource not found
- `err-unauthorized` (102): Unauthorized access attempt
- `err-invalid-input` (103): Invalid input parameters
- `err-patient-not-found` (104): Patient record not found
- `err-provider-not-verified` (105): Provider not verified
- `err-access-denied` (106): Access denied by permissions
- `err-already-exists` (107): Duplicate registration attempt

## Data Flow Architecture

1. **Patient Registration**: Encrypted personal info stored with privacy controls
2. **Provider Registration**: Professional credentials stored for verification
3. **Admin Verification**: Providers must be verified before accessing records
4. **Permission Granting**: Patients explicitly grant access to providers
5. **Record Creation**: Only verified providers with write access can create records
6. **Data Access**: Multiple authorization checks for all data access

## Compliance & Audit Features

- All medical records include timestamps for audit trails
- Emergency access protocols for critical care situations
- Patient-controlled data archival
- Comprehensive access logging capabilities
- HIPAA-compliant design patterns throughout

## Gas Optimization

- Efficient data structures with appropriate size limits
- Optimized map lookups and storage patterns
- Minimal on-chain data storage (only hashes and metadata)
- Smart contract functions designed for cost-effective execution