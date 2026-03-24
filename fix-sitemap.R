# fix-sitemap.R
# Strips /index.html from sitemap.xml so entries match canonical URLs.
# Runs automatically via post-render.

sitemap_path <- file.path("docs", "sitemap.xml")

if (file.exists(sitemap_path)) {
  sitemap <- readLines(sitemap_path, warn = FALSE)
  sitemap <- gsub("/index\\.html</loc>", "/</loc>", sitemap)
  writeLines(sitemap, sitemap_path)
  message("Sitemap cleaned: /index.html suffixes removed.")
} else {
  message("No sitemap.xml found in docs/. Skipping.")
}