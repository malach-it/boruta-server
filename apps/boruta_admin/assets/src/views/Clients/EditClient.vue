<template>
  <div class="edit-client">
    <div class="main header">
      <h1>Edit a client</h1>
    </div>
    <div class="ui container">
      <div class="ui large segment">
        <div class="ui attribute list">
          <div class="item">
            <span class="header">Client ID</span>
            <span class="description">{{ client.id }}</span>
          </div>
          <div class="item">
            <span class="header">Client secret</span>
            <span class="description">{{ client.secret }}</span>
          </div>
        </div>
      </div>
      <ClientForm :client="client" @submit="updateClient()" @back="back()" action="Update" />
    </div>
  </div>
</template>

<script>
import Client from '../../models/client.model'
import ClientForm from '../../components/Forms/ClientForm.vue'

export default {
  name: 'clients',
  components: {
    ClientForm
  },
  mounted () {
    const { clientId } = this.$route.params
    Client.get(clientId).then((client) => {
      this.client = client
    })
  },
  data () {
    return {
      errors: null,
      scopes: [],
      client: new Client()
    }
  },
  methods: {
    back () {
      this.$router.push({ name: 'client-list' })
    },
    updateClient () {
      return this.client.save().then(() => {
        this.$router.push({ name: 'client-list' })
      }).catch()
    }
  }
}
</script>
