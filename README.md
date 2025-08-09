# Decentralized Public Appliance Repair and Service Technician Licensing System

A comprehensive blockchain-based system for managing appliance repair technician licensing, warranty services, parts inventory, service scheduling, and consumer complaints.

## System Overview

This system consists of five interconnected smart contracts that manage the entire lifecycle of appliance repair services:

### 1. Technician Certification Contract (`technician-certification.clar`)
- Issues and manages licenses for appliance repair technicians
- Supports refrigerator, washer, and dryer repair specializations
- Tracks certification levels and expiration dates
- Handles license renewals and suspensions

### 2. Warranty Service Coordination Contract (`warranty-service.clar`)
- Manages authorized repair services for appliances under manufacturer warranty
- Tracks warranty status and coverage periods
- Coordinates between manufacturers, technicians, and consumers
- Validates warranty claims and authorizations

### 3. Parts Inventory Tracking Contract (`parts-inventory.clar`)
- Monitors availability of replacement parts for common appliance repairs
- Tracks part suppliers and pricing
- Manages inventory levels and reorder points
- Provides real-time availability status

### 4. Service Call Scheduling Contract (`service-scheduling.clar`)
- Coordinates repair appointments between technicians and customers
- Tracks response times and service completion
- Manages technician availability and scheduling conflicts
- Provides service history and performance metrics

### 5. Consumer Complaint Resolution Contract (`complaint-resolution.clar`)
- Handles disputes between customers and appliance repair companies
- Manages complaint lifecycle from filing to resolution
- Tracks resolution outcomes and technician performance
- Provides mediation and arbitration mechanisms

## Key Features

- **Decentralized Licensing**: No central authority controls technician certifications
- **Transparent Operations**: All transactions and certifications are publicly verifiable
- **Automated Compliance**: Smart contracts enforce licensing requirements automatically
- **Consumer Protection**: Built-in complaint resolution and dispute handling
- **Real-time Tracking**: Live updates on parts availability and service status
- **Performance Metrics**: Comprehensive tracking of technician and service quality

## Contract Architecture

Each contract operates independently while maintaining data consistency through standardized interfaces. The system uses:

- **Principal-based Authentication**: Technicians and consumers identified by Stacks addresses
- **Time-based Validations**: Automatic expiration handling for licenses and warranties
- **Event Logging**: Comprehensive audit trail for all system operations
- **Error Handling**: Robust error codes and validation mechanisms

## Getting Started

### Prerequisites
- Clarinet CLI installed
- Node.js and npm for testing
- Stacks wallet for contract deployment

### Installation
\`\`\`bash
git clone <repository-url>
cd appliance-repair-licensing
npm install
clarinet check
\`\`\`

### Testing
\`\`\`bash
npm test
\`\`\`

### Deployment
\`\`\`bash
clarinet deploy --testnet
\`\`\`

## Usage Examples

### Register as a Technician
\`\`\`clarity
(contract-call? .technician-certification register-technician
"John Smith"
"refrigerator"
u5)  ;; 5 years experience
\`\`\`

### Schedule a Service Call
\`\`\`clarity
(contract-call? .service-scheduling schedule-service
'SP1TECHNICIAN123
"Refrigerator not cooling"
u1640995200)  ;; timestamp
\`\`\`

### Check Parts Availability
\`\`\`clarity
(contract-call? .parts-inventory get-part-availability "compressor-model-123")
\`\`\`

## Error Codes

- `u100-u199`: Technician certification errors
- `u200-u299`: Warranty service errors
- `u300-u399`: Parts inventory errors
- `u400-u499`: Service scheduling errors
- `u500-u599`: Complaint resolution errors

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

MIT License - see LICENSE file for details

## Support

For technical support or questions, please open an issue in the repository.
