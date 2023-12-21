<template>
  <div class="organization-form">
    <div class="ui segment">
      <FormErrors :errors="organization.errors" v-if="organization.errors" />
      <form class="ui form" @submit.prevent="submit">
        <div class="field">
          <label>Name</label>
          <input type="text" v-model="organization.name" placeholder="wonder-organization" />
        </div>
        <div class="field">
          <label>Label</label>
          <input type="text" v-model="organization.label" placeholder="Wonder organization" />
        </div>
        <div class="ui invite-members segment" v-if="organization.isPersisted">
          <router-link class="ui fluid blue button" :to="{ name: 'invite-organization-members', params: { organizationId: organization.id } }">Invite members</router-link>
        </div>
        <h3>Email templates</h3>
        <div v-if="organization.isPersisted" class="ui segment">
          <router-link
            :to="{ name: 'edit-invite-organization-member-email-template', params: { organizationId: organization.id } }"
            class="ui fluid blue button">Edit invite organization member template</router-link>
        </div>
        <hr />
        <button class="ui right floated violet button" type="submit">{{ action }}</button>
        <a v-on:click="back()" class="ui button">Back</a>
      </form>
    </div>
  </div>
</template>

<script>
import FormErrors from './FormErrors.vue'

export default {
  name: 'organization-form',
  props: ['organization', 'action'],
  components: {
    FormErrors
  },
  methods: {
    back () {
      this.$emit('back')
    }
  }
}
</script>
