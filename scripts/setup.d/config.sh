# setup.d/config.sh — danh sách các thứ setup.sh lo. Sửa ở đây, không cần đụng vào module.
# Ghi đè cho riêng một máy: tạo setup.d/config.local.sh (nạp sau file này).

# CLI cho agent dùng thay MCP. Mỗi dòng: lệnh | gói cài bằng `uv tool` (trống = cài bằng gói hệ điều hành)
TOOLS="gh|
uv|
hf|huggingface_hub[cli]
kaggle|kaggle"

# CLI cần kiểm tra đăng nhập (mỗi cái có xử lý riêng trong module tools)
AUTH_TOOLS="gh hf kaggle"

# MCP ở scope user. Mỗi dòng: tên | lệnh khởi chạy. MCP theo project do /setup-project lo.
USER_MCP="context7|npx -y @upstash/context7-mcp"

# Script trong ~/.claude/scripts/ cần có lệnh gõ được ở mọi nơi (symlink vào ~/.local/bin)
LINKS="claude-sync show"