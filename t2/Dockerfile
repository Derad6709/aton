FROM nginx:alpine


RUN mkdir -p /etc/nginx/ssl
COPY nginx.conf /etc/nginx/nginx.conf
COPY certs /etc/nginx/ssl/
EXPOSE 80
EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]