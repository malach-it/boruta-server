<template>
  <div class="oauth-callback">
    <div class="ui container">
      <div class="ui loading placeholder segment"></div>
    </div>
  </div>
</template>

<script>
import oauth from '../services/oauth.service'

export default {
  name: 'oauth-callback',
  beforeRouteEnter (from, to, next) {
    oauth.callback().then(() => {
      if (window.frameElement) return

      next(oauth.storedLocation)
    }).catch(error => next(false))
  }
}
</script>
