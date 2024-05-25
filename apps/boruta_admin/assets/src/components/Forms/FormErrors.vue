<template>
  <div @click="hide()" class="form-errors ui error message" v-if="show" :class="{ 'inline': inline }">
    <div class="header">
      Could not save current record
    </div>
    <ul class="list">
      <li v-for="key in Object.keys(errors)" :key="key">
        <strong>{{ label(key) }} </strong> {{ errors[key][0] }}
      </li>
    </ul>
  </div>
</template>

<script>
const labels = {
  'access_token_ttl': 'Access token TTL',
  'authorization_code_ttl': 'Authorization code TTL',
  'authorized_scopes': 'Authorized scopes',
  'backend_id': 'Backend',
  'client_identity_providers': 'Client',
  'file': 'File',
  'forwarded_token_signature_alg': 'Forwarded token signature algorithm',
  'forwarded_token_signature_private_key': 'ID token signature private key',
  'forwarded_token_signature_public_key': 'ID token signature public key',
  'forwarded_token_signature_secret': 'ID token signature secret',
  'id_token_signature_alg': 'ID token signature algorithm',
  'id_token_ttl': 'ID token TTL',
  'identity_provider_id': 'identity provider',
  'is_default': 'Default',
  'name': 'Name',
  'password_hashing_opts': 'Password hashing options',
  'redirect_uris': 'Redirect URIs',
  'refresh_token_ttl': 'Refresh token TTL',
  'resource': 'Resource'
}

export default {
  name: 'FormErrors',
  props: ['errors', 'inline'],
  data () {
    return {
      show: true
    }
  },
  methods: {
    label(key) {
      return labels[key] === undefined ? key : labels[key]
    },
    hide () {
      this.show = false
    }
  }
}
</script>

<style scoped lang="scss">
.ui.error.message:not(.inline) {
  cursor: pointer;
  position: fixed;
  z-index: 1000;
  top: 4em;
  right: 1em;
}
</style>
