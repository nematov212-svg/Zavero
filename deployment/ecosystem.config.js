module.exports = {
  apps: [
    {
      name: 'zavero-backend',
      script: 'src/server.js',
      cwd: '/var/www/zavero/backend',
      instances: 'max',
      exec_mode: 'cluster',
      autorestart: true,
      watch: false,
      max_memory_restart: '1G',
      env: {
        NODE_ENV: 'production',
        PORT: 3000,
      },
      env_production: {
        NODE_ENV: 'production',
        PORT: 3000,
      },
      error_file: '/var/log/zavero/backend-err.log',
      out_file: '/var/log/zavero/backend-out.log',
      merge_logs: true,
      time: true,
    },
  ],
};
