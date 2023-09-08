<template>
  <div class="field edit-organizations">
    <div v-for="(organization, index) in currentOrganizations" class="field" :key="index">
      <div class="ui right icon input">
        <select type="text" v-model="organization.model" class="organizations-select">
          <option :value="organization" v-for="organization in organizationOptions(organization.model)" :key="organization.id">{{ organization.name }}</option>
        </select>
        <i v-on:click="deleteOrganization(organization)" class="close icon"></i>
      </div>
    </div>
    <a v-on:click.prevent="addOrganization()" class="ui blue fluid button">Add an organization</a>
  </div>
</template>

<script>
import Organization from '../../models/organization.model'

export default {
  name: 'OrganizationsField',
  props: ['currentOrganizations'],
  data () {
    return {
      organizations: []
    }
  },
  computed: {
    organizationOptions () {
      const vm = this
      return function (organization) {
        return vm.organizations.map((organization) => {
          if (organization.id === organization.id) {
            return organization
          }
          return organization
        })
      }
    }
  },
  mounted () {
    Organization.all().then(({ data: organizations }) => {
      this.organizations = organizations
    })
  },
  methods: {
    deleteOrganization (organization) {
      this.$emit('delete-organization', organization)
    },
    addOrganization () {
      this.$emit('add-organization')
    }
  }
}
</script>

<!-- Add "organizationd" attribute to limit CSS to this component only -->
<style organizationd lang="scss">
.edit-organizations {
  .ui.icon.input>i.icon.close {
    cursor: pointer;
    pointer-events: all;
  }
  .organizations-select {
    margin-right: 3em;
  }
}
</style>
