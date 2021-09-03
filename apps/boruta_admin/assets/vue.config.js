const path = require('path')

module.exports = {
  outputDir: path.resolve(__dirname, '../priv/static'),
  chainWebpack: config => {
    config.optimization.delete('splitChunks')
  },
  configureWebpack: {
    output: {
      filename: '[name].js'
    }
  },
  css: {
    extract: false
  }
}
