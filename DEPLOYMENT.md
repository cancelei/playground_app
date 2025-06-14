# Deployment Checklist for Playground App

This document outlines the steps needed to ensure the application is ready for production deployment using Caprover.

## Pre-Deployment Checklist

### 1. Database Configuration

- [x] Main database migrations are up to date
- [x] SolidQueue is properly installed
- [x] SolidQueue migrations are up to date
- [x] Database configuration in `config/database.yml` is using environment variables

### 2. Environment Variables

Ensure the following environment variables are set in your Caprover deployment:

- [ ] `SECRET_KEY_BASE` - For Rails encrypted cookies and sessions
- [ ] `RAILS_MASTER_KEY` - For Rails credentials
- [ ] `APPLICATION_HOST` - Your production domain name
- [ ] `APPLICATION_PROTOCOL` - Usually "https"
- [ ] `SMTP_*` settings - For email delivery
- [ ] `DATABASE_URL` - For main database connection
- [ ] `QUEUE_DATABASE_URL` - For SolidQueue database connection
- [ ] `ENABLE_SCHEDULERS` - Set to "true" to enable background jobs

See `.env.production.sample` for a complete list of required variables.

### 3. Background Jobs

- [x] SolidQueue is configured for production
- [x] Background job scheduler is enabled
- [x] Procfile includes both web and worker processes

### 4. Email Configuration

- [x] SMTP settings are configured
- [x] Welcome emails are set up to send immediately after registration
- [x] Inactivity warning emails are scheduled

### 5. User Authentication

- [x] Account confirmation requirement has been removed
- [x] Trackable columns are added to the users table
- [x] User model is updated to handle immediate login

## Deployment Process

1. **Build the Docker image**:
   ```bash
   docker build -t playground_app .
   ```

2. **Test the image locally**:
   ```bash
   docker run -p 3000:3000 -e SECRET_KEY_BASE=dummy playground_app
   ```

3. **Push to Caprover**:
   - Create a new app in Caprover
   - Set all required environment variables
   - Deploy using the Caprover CLI or web interface

4. **Verify Deployment**:
   - Check that the application is running
   - Verify that user registration works without confirmation
   - Confirm that background jobs are running

## Database Persistence

For production deployment, ensure database persistence by:

1. Using a managed PostgreSQL service, or
2. Setting up a PostgreSQL container with persistent volumes

## Monitoring

After deployment, monitor:

- Application logs for errors
- Background job execution
- Email delivery
- User registration and activity

## Troubleshooting

If you encounter issues:

1. Check application logs: `caprover app logs`
2. Verify environment variables are set correctly
3. Ensure database migrations have run: `caprover app exec "bin/rails db:migrate:status"`
4. Check SolidQueue status: `caprover app exec "bin/rails solid_queue:status"`
