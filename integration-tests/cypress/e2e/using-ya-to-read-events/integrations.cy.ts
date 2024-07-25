import path = require("path")
import { startNeovimWithYa } from "./startNeovimWithYa"

describe("integrations to other tools", () => {
  beforeEach(() => {
    cy.visit("http://localhost:5173")
  })

  it("can use grug-far.nvim to search and replace in the cwd", () => {
    startNeovimWithYa().then((dir) => {
      // wait until text on the start screen is visible
      cy.contains("If you see this text, Neovim is ready!")
      cy.typeIntoTerminal("{upArrow}")
      cy.typeIntoTerminal("/routes{enter}")
      cy.typeIntoTerminal("{rightArrow}")

      // contents in the directory should be visible in yazi
      cy.contains(dir.contents["routes/posts.$postId/adjacent-file.txt"].name)

      // close yazi and start grug-far.nvim
      cy.typeIntoTerminal("{control+g}")
      cy.contains("Grug FAR")

      // the directory we were in should be prefilled in grug-far.nvim's view
      cy.contains("testdirs")
      const p = path.join(dir.rootPathRelativeToTestEnvironmentDir, "routes")
      cy.contains(p)

      // by default, the focus is on the search field in normal mode. Type
      // something in the search field so we can see if results can be found
      cy.typeIntoTerminal("ithis")

      // maybe we don't want to make too many assertions on code we don't own
      // though, so for now we trust that it works in CI, and can verify it
      // works locally
    })
  })
})
