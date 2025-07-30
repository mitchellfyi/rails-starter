# RailsStarter

## Overview

RailsStarter is a Rails application built with modern development practices and AI-native features.

## Tech Stack

- **Ruby**: 3.2.3
- **Rails**: 8.1.0.alpha
- **Database**: SQLite

## Features

- User Management
- Authentication
- AI-Powered Development

## Getting Started

### Prerequisites

- Ruby 3.2.3
- Rails 8.1.0.alpha
- Node.js (for asset compilation)
- PostgreSQL or SQLite (database)

### Installation

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd railsstarter
   ```

2. Install dependencies:
   ```bash
   bundle install
   npm install
   ```

3. Setup the database:
   ```bash
   bin/rails db:create
   bin/rails db:migrate
   bin/rails db:seed
   ```

4. Start the development server:
   ```bash
   bin/rails server
   ```

## Development Commands

- `bin/rails server` - Start the development server
- `bin/rails console` - Start the Rails console
- `bin/rails test` - Run the test suite
- `bin/rails db:migrate` - Run database migrations
- `bin/rails db:seed` - Seed the database with sample data

## Documentation

- [Database Schema](docs/schema.md) - Database structure and relationships
- [API Documentation](docs/api.md) - API endpoints and usage
- [Developer Onboarding](docs/onboarding.md) - Getting started as a developer
- [AI Usage Guide](docs/ai_usage.md) - AI features and configuration

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License.
