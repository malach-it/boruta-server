<template>
  <div class="user-list">
    <Toaster :active="deleted" message="User has been deleted" type="warning" />
    <Toaster :active="errorMessage" :message="errorMessage" type="error" />
    <div class="main buttons">
      <router-link :to="{ name: 'user-import' }" class="ui violet main create button">Import users</router-link>
      <router-link :to="{ name: 'new-user' }" class="ui violet main create button">Add a user</router-link>
    </div>
    <div class="container">
      <div class="ui info message">
        Users are here the ones that can login to Boruta mirroring the backend to give the ability for the server to add security traits (confirmation, consent, or scope access).
      </div>
      <form class="ui form" @submit.prevent="throttledSearch()">
        <div class="field">
          <input type="text" v-model="userQuery" @keyup="throttledSearch()" placeholder="search" />
        </div>
      </form>
      <hr />
      <div class="ui three column stackable users grid" v-if="users.length">
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
              <div class="item">
                <span class="header">Backend</span>
                <span class="description"><router-link :to="{ name: 'edit-backend', params: { backendId: user.backend.id } }">{{ user.backend.name }}</router-link></span>
              </div>
            </div>
          </div>
        </div>
      </div>
      <hr />
      <div class="ui center aligned segment">
        <div class="total-entries">{{ totalEntries }} record(s)</div>
        <div class="ui pagination menu">
          <button
            :disabled="disableFirstPage"
            class="item"
            @click="goToPage(1)">
            &lt;
          </button>
          <button
            class="item"
            :class="{ 'active': currentPage == pageNumber }"
            v-for="pageNumber in meanPages"
            :key="pageNumber"
            @click="goToPage(pageNumber)">
            {{ pageNumber }}
          </button>
          <button
            :disabled="disableLastPage"
            class="item"
            @click="goToPage(this.totalPages)">
            &gt;
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { throttle } from 'lodash'
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
      userQuery: this.$route.query.q,
      totalPages: 1,
      totalEntries: 0,
      total_entries: 0
    }
  },
  computed: {
    throttledSearch () {
      return throttle(this.search, 500)
    },
    meanPages () {
      const meanPages = []

      let firstPage = this.currentPage - 1
      if (firstPage < 1) firstPage = 1
      let lastPage = firstPage + 2
      if (lastPage > this.totalPages) {
        lastPage = this.totalPages
        firstPage = lastPage - 2 < 1 ? 1 : lastPage - 2
      }

      for (let i = firstPage; i <= lastPage; i++) { meanPages.push(i) }

      return meanPages
    },
    disableFirstPage () {
      return this.meanPages[0] == 1
    },
    disableLastPage () {
      return this.meanPages.slice(-1) == this.totalPages
    }
  },
  methods: {
    getUsers (pageNumber, query) {
      User.all({ query, pageNumber }).then(({ data, currentPage, totalPages, totalEntries }) => {
        this.users = data
        this.totalPages = totalPages
        this.totalEntries = totalEntries
        this.currentPage = currentPage
      })
    },
    goToPage (pageNumber) {
      const query = { page: pageNumber }
      if (this.userQuery) query.q = this.userQuery

      this.$router.push({ name: 'user-list', query })
    },
    search () {
      const { userQuery } = this

      this.$router.push({ name: 'user-list', query: { q: userQuery } })
    },
    deleteUser (user) {
      if (!confirm('Are you sure ?')) return
      this.errorMessage = false
      this.deleted = false
      user.destroy().then(() => {
        this.getUsers(this.currentPage, this.userQuery)
      }).catch((error) => {
        this.errorMessage = error.response.data.message
      })
    }
  },
  watch: {
    '$route.query': {
      handler ({ page, q }) {
        this.getUsers(page, q)
      },
      deep: true,
      immediate: true
    }
  }
}
</script>

<style scoped lang="scss">
.users.grid {
  margin-bottom: 1em!important;
}
</style>
