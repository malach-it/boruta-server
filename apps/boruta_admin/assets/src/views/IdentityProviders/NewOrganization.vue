<template>
  <div class="new-organization">
    <Toaster :active="success" message="Organization has been created" type="success" />
    <div class="ui container">
      <OrganizationForm :organization="organization" @submit="createOrganization()" @back="back()" action="Create" />
    </div>
  </div>
</template>

<script>
import Organization from '../../models/organization.model'
import OrganizationForm from '../../components/Forms/OrganizationForm.vue'
import Toaster from '../../components/Toaster.vue'

export default {
  name: 'new-organization',
  components: {
    OrganizationForm,
    Toaster
  },
  data () {
    return {
      organization: new Organization(),
      success: false
    }
  },
  methods: {
    back () {
      this.$router.push({ name: 'organization-list' })
    },
    createOrganization () {
      this.success = false
      return this.organization.save().then(() => {
        this.success = true
        this.$router.push({ name: 'organization-list' })
      }).catch()
    }
  }
}
</script>
