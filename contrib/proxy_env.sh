export http_proxy="http://<%= @proxy %>"
export https_proxy="http://<%= @proxy %>"
export ftp_proxy="http://<%= @proxy %>"
export rsync_proxy="http://<%= @proxy %>"
export all_proxy="http://<%= @proxy %>"
export HTTP_PROXY="http://<%= @proxy %>"
export HTTPS_PROXY="http://<%= @proxy %>"
export FTP_PROXY="http://<%= @proxy %>"
export RSYNC_PROXY="http://<%= @proxy %>"
export ALL_PROXY="http://<%= @proxy %>"
export no_proxy="localhost,$(echo <%= @proxy %> | tr ":" "\n" | head -n 1),127.0.0.1,localaddress,.localdomain"
export NO_PROXY="$no_proxy"
