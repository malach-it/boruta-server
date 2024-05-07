import axios from 'axios'
import { addClientErrorInterceptor } from "../models/utils";

export default class ConfigurationFileUploader {
  static upload (file) {
    const accessToken = localStorage.getItem("access_token");

    let instance = axios.create({
      baseURL: `${window.env.BORUTA_ADMIN_BASE_URL}/api/configuration`,
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    instance = addClientErrorInterceptor(instance);

    const formData = new FormData()
    formData.append('file', file)

    return instance.post('/upload-configuration-file', formData, {
      headers: { 'Content-Type': 'multipart/form-data' }
    }).catch(({ response }) => {
      if (response.status == 400) {
        throw { errors: { file: ['is invalid'] } }
      } else {
        throw error
      }
    }).then(({ data }) => data)
  }
}
