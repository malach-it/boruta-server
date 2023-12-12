<template>
  <div class="invite-members">
    <Toaster :active="success" message="Members have been invited" type="success" />
    <div class="ui container">
      <div class="ui segment">
        <h2>Invite organization members</h2>
        <FormErrors :errors="errors" v-if="errors" />
        <form class="ui form" @submit.prevent="submit">
          <div class="field">
            <label>Client</label>
            <select v-model="invitationsClient">
              <option :value="client" v-for="client in clients">{{ client.name || client.id }}</option>
            </select>
          </div>
          <h3>Invitations</h3>
          <div class="field" v-for="(invitation, index) in invitations" :key="index">
            <div class="ui right icon input">
              <input type="email" v-model="invitation.email" placeholder="invited@email.host">
              <i v-on:click="deleteInvitation(invitation)" class="close icon"></i>
            </div>
          </div>
          <a class="ui fluid blue button" @click="addInvitation()">Add an invitation</a>
          <hr />
          <button class="ui fluid blue button">Send invitations</button>
        </form>
      </div>
    </div>
  </div>
</template>

<script>
import Organization from '../../../models/organization.model'
import Client from '../../../models/client.model'
import Toaster from '../../../components/Toaster.vue'
import FormErrors from '../../../components/Forms/FormErrors.vue'

export default {
  name: 'invite-members',
  components: {
    FormErrors,
    Toaster
  },
  data () {
    return {
      organization: new Organization(),
      invitations: [],
      clients: [],
      invitationsClient: null,
      errors: null,
      success: false
    }
  },
  mounted () {
    const { organizationId } = this.$route.params

    Organization.get(organizationId).then((organization) => {
      this.organization = organization
    })
    Client.all().then(clients => this.clients = clients)
  },
  methods: {
    back () {
      this.$router.push({ name: 'organization-list' })
    },
    addInvitation () {
      this.invitations.push({})
    },
    deleteInvitation (invitation) {
      this.invitations.splice(this.invitations.indexOf(invitation), 1)
    },
    submit () {
      this.success = false
      this.errors = null
      this.organization.sendInvitations(this.invitationsClient, this.invitations).then(() => {
        this.success = true
        this.invitations = []
        this.invitationsClient = null
      }).catch(errors => {
        this.errors = errors
      })
    }
  }
}
</script>

