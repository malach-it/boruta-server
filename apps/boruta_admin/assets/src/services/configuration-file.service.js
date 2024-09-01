import axios from 'axios'
import { addClientErrorInterceptor } from "../models/utils";

export default class ConfigurationFile {
  static get api () {
    const accessToken = localStorage.getItem("access_token");

    let instance = axios.create({
      baseURL: `${window.env.BORUTA_ADMIN_BASE_URL}/api/configuration`,
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    return addClientErrorInterceptor(instance);
  }

  static upload (file) {
    const formData = new FormData()
    formData.append('file', file)

    return this.api.post('/upload-configuration-file', formData, {
      headers: { 'Content-Type': 'multipart/form-data' }
    }).catch(({ response }) => {
      if (response.status == 400) {
        throw { errors: { file: ['is invalid'] } }
      } else {
        throw error
      }
    }).then(({ data }) => data)
  }

  static get (type = '') {
    return this.api.get(`/${type}`).then(({ data }) => {
      const configuration = data.data.find(({ name }) => name == 'configuration_file')
      return configuration && configuration.value || this.baseConfiguration
    }).catch(() => '')
  }

  static get baseConfiguration () {
    return `
---
version: "1.0"
configuration:
  client:
  identity_provider:
  backend:
  role:
  scope:
  gateway:
  microgateway:
  error_template:
    `
  }
}
