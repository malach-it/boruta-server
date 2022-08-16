<template>
  <div class="form-errors ui error message">
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
  'client_identity_providers': 'Client',
  'access_token_ttl': 'Access token TTL',
  'authorization_code_ttl': 'Authorization code TTL',
  'refresh_token_ttl': 'Refresh token TTL',
  'id_token_ttl': 'ID token TTL',
  'authorized_scopes': 'Authorized scopes',
  'identity_provider_id': 'identity provider',
  'redirect_uris': 'Redirect URIs',
  'id_token_signature_alg': 'ID token signature algorithm',
  'resource': 'Resource',
  'is_default': 'Default',
  'password_hashing_opts': 'Password hashing options'
}

export default {
  name: 'FormErrors',
  props: ['errors'],
  methods: {
    label(key) {
      return labels[key] === undefined ? key : labels[key]
    }
  }
}
</script>

<style scoped lang="scss">
.ui.error.message {
  position: fixed;
  z-index: 1000;
  top: 4em;
  right: 1em;
}
</style>
