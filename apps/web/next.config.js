/** @type {import('next').NextConfig} */
const publicApiUrl = process.env.NEXT_PUBLIC_API_URL || '/api/v1';

const internalApiUrl =
  process.env.API_INTERNAL_URL ||
  (publicApiUrl.startsWith('http')
    ? publicApiUrl
    : 'http://api:4000/api/v1');

const apiOrigin = internalApiUrl.replace(/\/api\/v1\/?$/, '');

const nextConfig = {
  output: 'standalone',
  async rewrites() {
    return [
      {
        source: '/api/v1/:path*',
        destination: `${apiOrigin}/api/v1/:path*`,
      },
    ];
  },
};

module.exports = nextConfig;
