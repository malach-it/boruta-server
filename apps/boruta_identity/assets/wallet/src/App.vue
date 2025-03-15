<template>
  <div class="main header">
    <router-link to="/">
      <img src="./assets/accounts/wallet/images/logo.png" />
    </router-link>
  </div>
  <router-view/>
</template>

<style lang="scss">
html, body {
  width: 100%;
  overflow-x: hidden;
}
.main.header {
  border-bottom: 1px solid #eee;
  padding: 1em;
  background: white;
  display: flex;
  justify-content: center;
  img {
    width: 4em;
  }
}
#app {
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  background: #f8f8f8;
  min-height: 100vh;
}

nav {
  text-align: center;
  padding: 30px;

  a {
    font-weight: bold;
    color: black;

    &:hover {
      color: #555;
    }
    &.router-link-exact-active {
      color: #f5ba00;
    }
  }
}
</style>
