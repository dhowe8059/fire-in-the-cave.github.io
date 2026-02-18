library(httr2)
library(dotenv)

# Load credentials
dotenv::load_dot_env()
pinata_key <- Sys.getenv("PINATA_API_KEY")
pinata_secret <- Sys.getenv("PINATA_API_SECRET")

# Commit message as argument, default if none provided
args <- commandArgs(trailingOnly = TRUE)
commit_msg <- ifelse(length(args) > 0, args[1], "site update")

# Step 1: Render Quarto site
message("Rendering Quarto site...")
system("quarto render")

# Step 2: Upload docs/ folder to Pinata
message("Uploading to Pinata...")

# Pinata requires multipart upload for folders
# We'll zip docs/ first then upload
zip_path <- tempfile(fileext = ".zip")
project_path <- "~/Sync/syncthing_quarto/fire-in-the-cave"
system(paste0("cd ", project_path, " && zip -r ", zip_path, " docs/"))

response <- request("https://api.pinata.cloud/pinning/pinFileToIPFS") |>
  req_headers(
    pinata_api_key = pinata_key,
    pinata_secret_api_key = pinata_secret
  ) |>
  req_body_multipart(
    file = curl::form_file(zip_path),
    pinataMetadata = '{"name":"fireinthecave-site"}'
  ) |>
  req_perform()

# Extract CID
result <- resp_body_json(response)
cid <- result$IpfsHash

message(paste0("Pinata upload complete. New CID: ", cid))
message(paste0("IPFS URL: https://gateway.pinata.cloud/ipfs/", cid))
message(">>> Paste this CID into Unstoppable Domains dashboard for fireinthecave.x")

# Step 3: Git push to GitHub Pages
message("Pushing to GitHub...")
system("git add .")
system(paste0('git commit -m "', commit_msg, '"'))
system("git push origin main")

message("Done. Both deployments complete.")
message(paste0("CID to update on Unstoppable: ", cid))