# AI-Powered Meal Planner

A React Remix application that generates weekly meal plans and shopping lists using OpenAI's GPT-4, with data persistence in Azure Table Storage.

## Features

- Generate weekly meal plans with 5 dinners
- Automatic shopping list generation
- Historical meal plan storage in Azure
- Modern, responsive UI with Tailwind CSS
- Containerized for Azure Container Apps deployment

## Prerequisites

Before you begin, you'll need to:

1. Install required tools:
   - [Node.js 18 or later](https://nodejs.org/)
   - [Docker Desktop](https://www.docker.com/products/docker-desktop/)
   - [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
   - [Azure Developer CLI](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd)
   - [Visual Studio Code](https://code.visualstudio.com/) (recommended)

2. Set up Azure account:
   - Sign up for an [Azure account](https://azure.microsoft.com/free/) if you don't have one
   - Install the [Azure Tools extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode.vscode-node-azure-pack) for VS Code (recommended)

3. Get an OpenAI API key:
   - Sign up for an [OpenAI account](https://platform.openai.com/signup)
   - Create an API key in your [OpenAI dashboard](https://platform.openai.com/api-keys)

## Azure Setup Guide

### 1. Initial Azure Setup

1. Open a terminal (PowerShell recommended on Windows) and log in to Azure:
   ```powershell
   azd auth login (login with azd)
   az login (login with Azure CLI)
   ```
   This will open your browser for authentication.

2. If you have multiple subscriptions, select the one you want to use:
   ```powershell
   # List your subscriptions
   az account list --output table
   
   # Set your desired subscription
   az account set --subscription "<subscription-name-or-id>"
   ```

## Local Development Setup

1. Clone and install dependencies:
   ```powershell
   git clone <repository-url>
   cd meal-planner
   npm install
   ```

2. Copy the environment file template:
   ```powershell
   Copy-Item .env.example .env
   ```

3. Configure your environment variables in the `.env` file:
   ```plaintext
   AZURE_STORAGE_ACCOUNT_NAME=<storage-account-name>  # Will be created by Bicep deployment
   OPENAI_API_KEY=<your-openai-api-key>              # From your OpenAI dashboard
   ```

4. Start the development server:
   ```powershell
   npm run dev
   ```
   The app will be available at http://localhost:3000

## Deployment to Azure

You have two options for deploying to Azure:

### Using Azure Developer CLI (Recommended)

The simplest way to deploy is using the Azure Developer CLI (`azd`):

1. Install the [Azure Developer CLI](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd)

2. Run the following command to deploy all resources:
   ```powershell
   azd up
   ```
   This will:
   - Create all necessary Azure resources
   - Build and push the Docker image
   - Deploy the application
   - Set up all required configurations

## Architecture

- **Frontend**: React Remix for server-side rendering and client interactions
- **Backend**: Express.js server handling API requests
- **AI**: OpenAI GPT-4 for meal plan generation
- **Storage**: Azure Table Storage for meal plan history
- **Infrastructure**: Azure Container Apps for hosting
- **Authentication**: Managed Identity for secure storage access

## Styling

Built with Tailwind CSS for a responsive and modern UI. See the [Tailwind docs](https://tailwindcss.com/docs) for customization options.

## Estimated Costs

- **Azure Container Apps**: Pay-per-use, starts at ~$0/month for minimal usage
- **Azure Container Registry**: Basic tier ~$5/month
- **Azure Storage**: Pay-per-use, typically <$1/month for this usage
- **OpenAI API**: Pay-per-use, varies based on usage (~$0.03 per meal plan generation)

## Clean Up Resources

To avoid incurring costs when not using the application:

```powershell
az group delete --name <resource-group-name> --yes --no-wait
```
This will delete all resources in the resource group.
