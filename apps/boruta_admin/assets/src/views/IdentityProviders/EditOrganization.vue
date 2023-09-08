<template>
  <div class="edit-organization">
    <Toaster :active="success" message="Organization has been updated" type="success" />
    <div class="ui container">
      <div class="ui segment">
        <div class="ui attribute list">
          <div class="item">
            <span class="header">OrganizationId</span>
            <span class="description">{{ organization.id }}</span>
          </div>
        </div>
      </div>
      <OrganizationForm :organization="organization" @submit="updateOrganization()" @back="back()" action="Update" />
    </div>
  </div>
</template>

<script>
import Organization from '../../models/organization.model'
import OrganizationForm from '../../components/Forms/OrganizationForm.vue'
import Toaster from '../../components/Toaster.vue'

export default {
  name: 'edit-organization',
  components: {
    OrganizationForm,
    Toaster
  },
  mounted() {
    const { organizationId } = this.$route.params
    Organization.get(organizationId).then((organization) => {
      this.organization = organization
    })
  },
  data() {
    return {
      organization: new Organization(),
      success: false
    }
  },
  methods: {
    back() {
      this.$router.push({ name: 'organization-list' })
    },
    async updateOrganization () {
      this.success = false
      return this.organization.save().then(() => {
        this.success = true
      }).catch()
    }
  }
}
</script>
