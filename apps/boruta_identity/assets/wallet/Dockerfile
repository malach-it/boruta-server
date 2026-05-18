FROM node:21.4 AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . /app
RUN npm run build

RUN npm install -g serve

CMD ["serve", "-s", "--listen",  "tcp://0.0.0.0:3000",  "dist"]
