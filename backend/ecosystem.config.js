module.exports = {
  apps: [
    {
      name: 'zavero-backend',
      script: 'src/server.js',
      instances: 1,
      autorestart: true,
      max_restarts: 15,
      restart_delay: 3000,
      watch: false,
      max_memory_restart: '1G',
      env: {
        NODE_ENV: 'production',
        PORT: process.env.PORT || 3000,
      },
      env_development: {
        NODE_ENV: 'development',
        PORT: 3000,
      },
    },
  ],
};
