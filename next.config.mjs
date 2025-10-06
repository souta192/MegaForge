/** @type {import('next').NextConfig} */
const repoName = process.env.GH_PAGES_REPO || ""; // e.g. "megaforge"
const isProjectPage = Boolean(repoName);
const basePath = isProjectPage ? `/${repoName}` : "";
const assetPrefix = basePath || "";

const nextConfig = {
  output: "export",
  images: { unoptimized: true },
  basePath,
  assetPrefix,
  trailingSlash: true
};

export default nextConfig;
