library(httr2)
library(dotenv)
library(curl)
library(httr)
library(jsonlite)

# Load credentials
dotenv::load_dot_env()
pinata_key    <- Sys.getenv("PINATA_API_KEY")
pinata_secret <- Sys.getenv("PINATA_API_SECRET")
ud_api_key    <- Sys.getenv("UD_API_KEY")
ud_domain     <- "fireinthecave.x"

# Commit message as argument, default if none provided
args <- commandArgs(trailingOnly = TRUE)
commit_msg <- ifelse(length(args) > 0, args[1], "site update")

project_path <- "~/Sync/syncthing_quarto/fire-in-the-cave"
docs_path    <- path.expand(file.path(project_path, "docs"))

# ── Step 1: Render ────────────────────────────────────────────────────────────
message("Rendering Quarto site...")
render_result <- system("quarto render")
if (render_result != 0) stop("Quarto render failed. Aborting.")

# ── Step 2: Upload docs/ folder to Pinata (Modernized) ──────────────────────
message("Uploading to Pinata...")

# Use httr2 to build a multi-part request for the directory
req_pinata <- request("https://api.pinata.cloud/pinning/pinFileToIPFS") %>%
  req_headers(
    pinata_api_key = pinata_key,
    pinata_secret_api_key = pinata_secret
  )

# Gather files
all_files <- list.files(docs_path, recursive = TRUE, full.names = TRUE)
rel_paths  <- substring(all_files, nchar(docs_path) + 2)

# Create the body list
body_list <- list()

# Add the metadata and options
body_list[["pinataMetadata"]] <- jsonlite::toJSON(list(name = "fireinthecave-site"), auto_unbox = TRUE)
body_list[["pinataOptions"]]  <- jsonlite::toJSON(list(cidVersion = 1), auto_unbox = TRUE)

# Add each file with its relative path in the directory structure
# This is what prevents the .zip or "flat file" issues
for (i in seq_along(all_files)) {
  body_list[[paste0("file", i)]] <- curl::form_file(all_files[i], type = NULL, name = rel_paths[i])
}

# Perform the request
pin_response <- req_pinata %>%
  req_body_multipart(!!!body_list) %>%
  req_perform()

result <- resp_body_json(pin_response)
cid <- result$IpfsHash

message(paste0("  Upload complete. CID: ", cid))

# ── Step 3: Update Unstoppable Domains (The "Clean" Update) ──────────────────
# Ensure the record is set exactly to the CID
# Note: Some UD domains require /ipfs/ prefix, but usually just the CID
records_to_update <- list(
  `dweb.ipfs.hash` = cid,
  `browser.redirect_url` = paste0("https://gateway.pinata.cloud/ipfs/", cid)
)

# ... your Step 3 code continues here ...
message("Updating Unstoppable Domains...")

if (nchar(ud_api_key) == 0) {
  message("  UD_API_KEY not set — skipping. Paste CID manually:")
  message(paste0("  CID: ", cid))
} else {
  ud_url <- paste0("https://api.unstoppabledomains.com/domains/", ud_domain)
  
  ud_response <- request(ud_url) |>
    req_headers(
      Authorization  = paste("Bearer", ud_api_key),
      `Content-Type` = "application/json"
    ) |>
    req_body_json(list(
      records = list(`dweb.ipfs.hash` = cid)
    )) |>
    req_method("PATCH") |>
    req_error(is_error = \(resp) FALSE) |>
    req_perform()
  
  message(paste0("  UD status: ", resp_status(ud_response)))
  message(resp_body_string(ud_response))
} 

# ── Step 4: Git push to GitHub Pages ─────────────────────────────────────────
message("Pushing to GitHub...")
system(paste0("cd ", path.expand(project_path), " && git add ."))
system(paste0("cd ", path.expand(project_path), 
              ' && git commit -m "', commit_msg, '"'))
system(paste0("cd ", path.expand(project_path), " && git push origin main"))

# ── Done ──────────────────────────────────────────────────────────────────────
message("─────────────────────────────────────")
message("Done.")
message(paste0("GitHub Pages: https://fireinthecave.com"))
message(paste0("IPFS:         https://gateway.pinata.cloud/ipfs/", cid))
message(paste0("CID:          ", cid))