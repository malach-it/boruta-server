FROM node:21.4 AS builder

COPY . /app

WORKDIR /app

RUN npm ci
RUN npm run build

RUN npm install -g serve

CMD ["serve", "-s", "--listen",  "tcp://0.0.0.0:3000",  "dist"]
