ARG RUNTIME_ENV

# BUILD
FROM node:18.16.1-alpine3.18 AS build

ARG SITE

WORKDIR /app

COPY . .

RUN npm i
RUN npm run build
RUN npm run check:all
RUN npm run test:ci
RUN sed -i "s@<SITE>@${SITE}@g" ./dist/robots.txt

# RUNTIME STAGE
FROM nginx:1.25.1-alpine AS runtime-stage

ARG AUTH_LOGIN
ARG AUTH_PASSWORD

COPY ./docker/nginx-stage.conf /etc/nginx/conf.d/template
COPY ./docker/.htpasswd /etc/nginx/.htpasswd
COPY --from=build /app/dist /usr/share/nginx/html

RUN sed -i "s@AUTH_LOGIN@${AUTH_LOGIN}@g" /etc/nginx/.htpasswd && \
    sed -i "s@AUTH_PASSWORD@${AUTH_PASSWORD}@g" /etc/nginx/.htpasswd

# RUNTIME PRODUCTION
FROM nginx:1.25.1-alpine AS runtime-production

COPY ./docker/nginx-production.conf /etc/nginx/conf.d/template
COPY --from=build /app/dist /usr/share/nginx/html

# RUNTIME
FROM runtime-${RUNTIME_ENV} AS runtime

ENV PORT=3000

CMD sh -c "envsubst '\$PORT' < /etc/nginx/conf.d/template > /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"

EXPOSE 3000
