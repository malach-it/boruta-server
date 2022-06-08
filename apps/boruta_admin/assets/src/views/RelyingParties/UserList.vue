<template>
  <div class="user-list">
    <Toaster :active="deleted" message="User has been deleted" type="warning" />
    <Toaster :active="errorMessage" :message="errorMessage" type="error" />
    <div class="container">
      <div class="ui three column stackable grid" v-if="users.length">
        <div v-for="user in users" class="column" :key="user.id">
          <div class="ui user highlightable segment">
            <div class="actions">
              <router-link
                :to="{ name: 'edit-user', params: { userId: user.id } }"
                class="ui tiny blue button">edit</router-link>
              <a v-on:click="deleteUser(user)" class="ui tiny red button">delete</a>
            </div>
            <div class="ui attribute list">
              <div class="item">
                <span class="header">Email</span>
                <span class="description">{{ user.email }}</span>
              </div>
            </div>
          </div>
        </div>
      </div>
      <div class="ui center aligned segment">
        <div class="ui pagination menu">
          <a
            class="item"
            :class="{ 'active': currentPage == pageNumber }"
            v-for="pageNumber in totalPages"
            @click="goToPage(pageNumber)">
            {{ pageNumber }}
          </a>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import User from '../../models/user.model'
import Toaster from '../../components/Toaster.vue'

export default {
  name: 'user-list',
  components: {
    Toaster
  },
  data () {
    return {
      users: [],
      deleted: false,
      errorMessage: false,
      currentPage: this.$route.query.page,
      page_size: 12,
      totalPages: 1,
      total_entries: 0
    }
  },
  mounted () {
    this.getUsers(this.currentPage)
  },
  methods: {
    getUsers (pageNumber) {
      User.all({ pageNumber }).then(({ data, currentPage, totalPages }) => {
        this.users = data
        this.totalPages = totalPages
        this.currentPage = currentPage
      })
    },
    goToPage(pageNumber) {
      this.$router.push({ name: 'user-list', query: { page: pageNumber } })
    },
    deleteUser (user) {
      if (!confirm('Are you sure ?')) return
      this.errorMessage = false
      this.deleted = false
      user.destroy().then(() => {
        this.deleted = true
        this.users.splice(this.users.indexOf(user), 1)
      }).catch((error) => {
        this.errorMessage = error.response.data.message
      })
    }
  },
  watch: {
    '$route.query.page': {
      handler(pageNumber) {
        this.getUsers(pageNumber)
      },
      deep: true,
      immediate: true
    }
  }
}
</script>

<style scoped lang="scss">
</style>
