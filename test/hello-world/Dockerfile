FROM nginx:alpine

# Custom config: listen on port 3000 (matches provision.sh ports_exposes)
# and expose /api/health (matches provision.sh health_check_path)
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/index.html

EXPOSE 3000
