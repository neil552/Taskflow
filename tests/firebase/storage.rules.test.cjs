const fs = require('node:fs');
const path = require('node:path');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {ref, uploadBytes, getBytes, deleteObject} = require('firebase/storage');

// Comprueba que los avatares se mantengan privados y dentro de sus límites.
describe('TaskFlow Storage rules', function () {
  let environment;

  before(async function () {
    environment = await initializeTestEnvironment({
      projectId: 'demo-taskflow',
      storage: {
        rules: fs.readFileSync(
          path.join(__dirname, '..', '..', 'storage.rules'),
          'utf8',
        ),
      },
    });
  });

  beforeEach(async function () {
    await environment.clearStorage();
  });

  after(async function () {
    await environment.cleanup();
  });

  // El dueño conserva control completo sobre su propio archivo de avatar.
  it('allows the owner to upload, read and delete an image avatar', async function () {
    const storage = environment.authenticatedContext('alice').storage();
    const avatar = ref(storage, 'user_avatars/alice.jpg');
    const image = new Uint8Array([0xff, 0xd8, 0xff]);

    await assertSucceeds(
      uploadBytes(avatar, image, {contentType: 'image/jpeg'}),
    );
    await assertSucceeds(getBytes(avatar));
    await assertSucceeds(deleteObject(avatar));
  });

  // Valida aislamiento por UID, tipo MIME y límite de tamaño del archivo.
  it('denies other users, unauthenticated access, oversized and non-image uploads', async function () {
    const aliceStorage = environment.authenticatedContext('alice').storage();
    const aliceAvatar = ref(aliceStorage, 'user_avatars/alice.jpg');
    await assertSucceeds(
      uploadBytes(aliceAvatar, new Uint8Array([1]), {
        contentType: 'image/jpeg',
      }),
    );

    const bobStorage = environment.authenticatedContext('bob').storage();
    await assertFails(getBytes(ref(bobStorage, 'user_avatars/alice.jpg')));
    await assertFails(
      uploadBytes(ref(bobStorage, 'user_avatars/bob.jpg'), new Uint8Array([1]), {
        contentType: 'text/plain',
      }),
    );
    await assertFails(
      uploadBytes(
        ref(aliceStorage, 'user_avatars/large.jpg'),
        new Uint8Array(5 * 1024 * 1024 + 1),
        {contentType: 'image/jpeg'},
      ),
    );

    const anonymousStorage = environment.unauthenticatedContext().storage();
    await assertFails(
      getBytes(ref(anonymousStorage, 'user_avatars/alice.jpg')),
    );
  });
});
