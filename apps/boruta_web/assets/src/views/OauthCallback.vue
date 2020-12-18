<template>
  <div class="oauth-callback">
    You are being redirected...
  </div>
</template>

<script>
import oauth from '@/services/oauth.service'

export default {
  name: 'oauth-callback',
  mounted () {
    oauth.callback().then(() => {
      this.$store.dispatch('getCurrentUser')
      this.$router.push({ name: 'home' })
    })
  }
}
</script>
