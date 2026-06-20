import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  /* Docker 部署：standalone 输出模式，生成最小化独立服务器 */
  output: "standalone",
};

export default nextConfig;
