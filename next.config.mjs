import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/** @type {import('next').NextConfig} */
const nextConfig = {
  // A stray lockfile in a parent directory makes Next.js infer the wrong
  // workspace root, so pin it to this project.
  outputFileTracingRoot: __dirname,
};

export default nextConfig;
