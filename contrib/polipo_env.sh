export http_proxy=http://<%= @proxy_cache %>:<%= @cache.polipo_port %>
export ftp_proxy=http://<%= @proxy_cache %>:<%= @cache.polipo_port %>
export https_proxy=https://<%= @proxy_cache %>:<%= @cache.polipo_port %>
