<template>
  <div class="edit-client">
    <Toaster :active="success" message="Client has been updated" type="success" />
    <div class="ui container">
      <div class="ui segment">
        <div class="ui attribute list">
          <div class="item">
            <span class="header">Client ID</span>
            <span class="description">{{ client.id }}</span>
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
import Toaster from '../../components/Toaster.vue'

export default {
  name: 'clients',
  components: {
    ClientForm,
    Toaster
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
      success: false,
      client: new Client()
    }
  },
  methods: {
    back () {
      this.$router.push({ name: 'client-list' })
    },
    updateClient () {
      this.success = false
      return this.client.save().then(() => {
        this.success = true
      }).catch()
    }
  }
}
</script>

