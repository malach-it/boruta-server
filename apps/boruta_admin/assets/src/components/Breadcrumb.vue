<template>
  <div class="ui breadcrumb">
    <span v-for="(item, index) in items" :key="item.path">
      <span v-if="index + 1 < items.length">
        <router-link :to="item.path" class="section">{{ item.label }}</router-link>
        <i class="right angle icon divider"></i>
      </span>
      <span class="section" v-else>
        {{ item.label }}
      </span>
    </span>
  </div>
  <hr />
</template>

<script>
const labels = {
  'root': 'Home',
  'not-found': 'Not found',
  'bad-request': 'Bad request',
  'dashboard': 'Dashboard',
  'request-logs': 'Requests',
  'business-event-logs': 'Business Events',
  'identity-providers': "identity providers",
  'new-identity-provider': 'Create',
  'identity-provider': ({ params }) => params.identityProviderId,
  'edit-layout-template': 'Edit layout template',
  'edit-session-template': 'Edit login template',
  'edit-choose-session-template': 'Edit choose session template',
  'edit-registration-template': 'Edit registration template',
  'edit-edit-user-template': 'Edit user edition template',
  'edit-new-reset-password-template': 'Edit send reset password instructions template',
  'edit-edit-reset-password-template': 'Edit reset password template',
  'edit-new-confirmation-template': 'Edit send confirmation instructions template',
  'edit-new-consent-template': 'Edit consent template',
  'backends': 'Backends',
  'backend': ({ params }) => params.backendId,
  'new-backend': 'Create',
  'edit-confirmation-instructions-email-template': 'Edit confirmation instructions email template',
  'edit-reset-password-instructions-email-template': 'Edit reset password instructions email template',
  'users': 'Users',
  'new-user': 'Create',
  'user-import': 'Import',
  'edit-user': ({ params }) => params.userId,
  'clients': 'Clients',
  'key-pair-list': 'Key pairs',
  'new-client': 'Create',
  'client': ({ params }) => params.clientId,
  'upstreams': 'Upstreams',
  'new-upstream': 'Create',
  'upstream': ({ params }) => params.upstreamId,
  'scopes': 'Scopes',
  'configuration': 'Configuration',
  'error-template-list': 'Error templates',
  'edit-bad-request-template': 'Edit bad request template',
  'edit-forbidden-template': 'Edit forbidden template',
  'edit-not-found-template': 'Edit not found template',
  'edit-internal-server-error-template': 'Edit internal server error template'
}

export default {
  name: 'breadcrumb',
  computed: {
    items () {
      const items = this.$route.matched
        .filter(({ name }) => name)
        .filter(({ name }) => labels[name])
        .map((route) => {
          const { name } = route
          const label = labels[name]

          return {
            label: (label instanceof Function) ? label(this.$route) : label,
            path: { name, params: this.$route.params }
          }
        })

      return items
    }
  }
}
</script>

<style scoped lang="scss">
.ui.breadcrumb {
  font-size: 1em;
  line-height: 1em;
  padding: 1rem 1rem 0 1rem;
  .section {
    display: inline;
  }
}
</style>
