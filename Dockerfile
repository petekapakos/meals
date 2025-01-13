# Build stage
FROM node:20-slim as build

WORKDIR /app

# Copy package files and config files
COPY package*.json ./
COPY vite.config.ts ./
COPY tsconfig.json ./
COPY postcss.config.js ./
COPY tailwind.config.ts ./

# Install dependencies
RUN npm ci

# Copy source code
COPY . .

# Build the app
RUN npm run build

# Production stage
FROM node:20-slim

WORKDIR /app

# Copy package files and install production dependencies
COPY package*.json ./
RUN npm ci --production

# Copy built assets from build stage
COPY --from=build /app/build/server /app/build/server
COPY --from=build /app/build/client /app/build/client
COPY --from=build /app/server.js ./server.js

# Set environment variables
ENV NODE_ENV=production

# Expose the port your app runs on
EXPOSE 3000

# Start the app
CMD ["npm", "start"]