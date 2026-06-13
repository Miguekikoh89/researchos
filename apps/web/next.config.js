/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  async rewrites() {
    return [
      {
        source: '/api/v1/:path*',
        destination: 'http://api:4000/api/v1/:path*',
      },
    ];
  },
};
module.exports = nextConfig;
