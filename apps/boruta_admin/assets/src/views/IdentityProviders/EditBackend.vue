<template>
  <div class="edit-backend">
    <Toaster :active="success" message="backend has been updated" type="success" />
    <div class="ui container">
      <div class="ui segment">
        <div class="ui attribute list">
          <div class="item">
            <span class="header">backend ID</span>
            <span class="description">{{ backend.id }}</span>
          </div>
          <div class="item">
            <span class="header">Name</span>
            <span class="description">{{ backend.name }}</span>
          </div>
        </div>
      </div>
      <BackendForm :backend="backend" @submit="updateBackend()" @back="back()" action="Update" />
    </div>
  </div>
</template>

<script>
import Backend from '../../models/backend.model'
import BackendForm from '../../components/Forms/BackendForm.vue'
import Toaster from '../../components/Toaster.vue'

export default {
  name: 'edit-backend',
  components: {
    BackendForm,
    Toaster
  },
  mounted () {
    const { backendId } = this.$route.params
    Backend.get(backendId).then((backend) => {
      this.backend = backend
    })
  },
  data () {
    return {
      backend: new Backend(),
      success: false
    }
  },
  methods: {
    back () {
      this.$router.push({ name: 'backend-list' })
    },
    updateBackend () {
      this.success = false
      return this.backend.save().then(() => {
        this.success = true
      }).catch()
    }
  }
}
</script>
