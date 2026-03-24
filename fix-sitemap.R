# fix-sitemap.R
# ------------------------------------------------------------------
# Ensures sitemap.xml URLs match the canonical URL format.
#
# Quarto with canonical-url: true generates canonical tags.
# This script ensures the sitemap entries use the same format
# so Google does not see conflicting signals.
#
# Also reports what it finds so you can verify.
#
# Runs automatically via post-render in _quarto.yml:
#   project:
#     post-render:
#       - "Rscript fix-sitemap.R"
# ------------------------------------------------------------------

sitemap_path <- file.path("docs", "sitemap.xml")

if (file.exists(sitemap_path)) {
  sitemap <- readLines(sitemap_path, warn = FALSE)
  
  # Count entries
  n_urls <- length(grep("<loc>", sitemap))
  
  # Check for /index.html pattern (subfolder-based sites)
  n_index <- length(grep("/index\\.html</loc>", sitemap))
  
  # Check for .html extension pattern (flat file sites)
  n_html <- length(grep("\\.html</loc>", sitemap))
  
  # Report what we found
  message("fix-sitemap.R: Found ", n_urls, " URLs in sitemap.")
  message("fix-sitemap.R: ", n_html, " end in .html")
  message("fix-sitemap.R: ", n_index, " end in /index.html")
  
  # If using index.html pattern, clean those
  if (n_index > 0) {
    sitemap <- gsub("/index\\.html</loc>", "/</loc>", sitemap)
    writeLines(sitemap, sitemap_path)
    message("fix-sitemap.R: Cleaned /index.html suffixes.")
  }
  
  message("fix-sitemap.R: Sitemap check complete. No errors.")
  
} else {
  message("fix-sitemap.R: No sitemap.xml found in docs/. Skipping.")
}