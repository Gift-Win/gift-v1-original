
const { expect } = require('chai')

const nullAddress = '0x0000000000000000000000000000000000000000'

describe('Gift contract', function () {
  let gift, admin1, hippyKing1, hippyKing2, user1

  before(async () => {
    [admin1, hippyKing1, hippyKing2, user1] = await ethers.getSigners()

    const Gift = await ethers.getContractFactory('GiftV1')
    gift = await Gift.deploy(admin1.address)
  })

  describe('hippy tests', function () {
    it('should not have a hippy king', async function () {
      await expect(await gift.hippyKing()).to.equal(nullAddress)
    })

    it('only bidder with enough salt can be hippy king, and only when not paused', async function () {
      const hippyFee = await gift.hippyFee()

      await expect(gift.connect(hippyKing1).crownMyself()).to.be.revertedWith('Invalid fee')

      await expect(gift.connect(admin1).pause()).to.emit(gift, 'Paused')

      await expect(
        gift.connect(hippyKing1).crownMyself({ value: hippyFee.add(ethers.utils.parseEther(String(5))) })
      ).to.be.revertedWith('Pausable: paused')

      await expect(gift.connect(admin1).unpause()).to.emit(gift, 'Unpaused')

      await expect(
        gift.connect(hippyKing1).crownMyself({ value: hippyFee.add(ethers.utils.parseEther(String(5))) })
      ).to.emit(gift, 'NewKing')

      await expect(await gift.hippyKing()).to.equal(hippyKing1.address)
    })

    it('only hippy king can loose their mind', async function () {
      await expect(gift.connect(user1).decree()).to.be.revertedWith('Not king')

      await expect(gift.connect(hippyKing1).decree()).to.be.emit(gift, 'Hippy')

      await expect(await gift.hippy()).to.equal(true)
    })

    it('only hippy king can regain their mind', async function () {
      await expect(gift.connect(user1).decree()).to.be.reverted // With(...)

      await expect(gift.connect(hippyKing1).decree()).to.be.emit(gift, 'Hippy')

      await expect(await gift.hippy()).to.equal(false)
    })

    it('only hippy king can abdicate, and only when not paused', async function () {
      await expect(gift.connect(user1).abdicateCrown('I AM A COWARD')).to.be.revertedWith('Not king')

      await expect(gift.connect(admin1).pause()).to.emit(gift, 'Paused')

      await expect(
        gift.connect(hippyKing1).abdicateCrown('I AM A COWARD')
      ).to.be.revertedWith('Pausable: paused')

      await expect(gift.connect(admin1).unpause()).to.emit(gift, 'Unpaused')
      await expect(gift.connect(hippyKing1).abdicateCrown('I AM A COWARD')).to.emit(gift, 'Shame')
    })

    it('only admins can change hippy fee', async function () {
      const hippyFee = await gift.hippyFee()
      const newFee = hippyFee.add(ethers.utils.parseEther(String(5)))

      await expect(gift.connect(user1).setHippyFee(newFee)).to.be.revertedWith('Not authorized')

      await expect(gift.connect(admin1).setHippyFee(newFee)).to.be.emit(gift, 'NewHippyFee')

      await expect((await gift.hippyFee())).to.equal(newFee)
    })

    it('other bidders too can become hippy king', async function () {
      const hippyFee = await gift.hippyFee()

      await expect(
        gift.connect(hippyKing2).crownMyself({ value: hippyFee.add(ethers.utils.parseEther(String(5))) })
      ).to.emit(gift, 'NewKing')

      await expect(gift.connect(hippyKing2).decree()).to.be.emit(gift, 'Hippy')
    })

    it('only admins can mutiny', async function () {
      await expect(await gift.hippyKing()).to.equal(hippyKing2.address)
      await expect(await gift.hippy()).to.equal(true)

      await expect(gift.connect(user1).mutiny()).to.be.reverted // With(...)

      await expect(gift.connect(admin1).mutiny()).to.be.emit(gift, 'Mutiny')

      await expect((await gift.hippyKing())).to.equal(gift.address)
      await expect((await gift.hippy())).to.equal(false)
    })
  })
})
